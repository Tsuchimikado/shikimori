# TODO: отрефакторить толстый контроллер
class AnimesCollectionController < ShikimoriController
  helper_method :klass, :entries_per_page
  caches_action :index, :menu, CacheHelper.cache_settings

  # страница каталога аниме/манги
  def index
    mylist_redirect_check
    build_background

    unless shikimori?
      params[:is_adult] = AnimeOnlineDomain::adult_host?(request)
      params[:with_censored] = params[:is_adult]
    end

    query = AniMangaQuery.new(klass, params, current_user).fetch

    if params[:search]
      noindex && nofollow
      raise AgeRestricted if params[:search] =~ /\b(?:sex|секс|porno?|порно)\b/ && censored_forbidden?
      @page_title = "Поиск “#{SearchHelper.unescape params[:search]}”"
    end

    # для сезонов без пагинации
    @entries = if params[:season].present? && params[:season] =~ /^([a-z]+_\d+,?)+$/ && !params[:ids_with_sort].present?
      @render_by_kind = true
      fetch_wo_pagination query
    else
      fetch_with_pagination query
    end
    one_found_redirect_check

    if params[:rel] || request.url.include?('order') ||
        @description.blank? || @entries.empty? ||
        params.any? {|k,v| k != 'genre' && v.kind_of?(String) && v.include?(',') }
      noindex and nofollow
    end

    @description = [] if params_page > 1 && !turbolinks_request?
    @title_notice = "" if params_page > 1 && !turbolinks_request?

    description @description.join(' ')
    keywords klass.keywords_for(params[:season], params[:type], @entry_data[:genre], @entry_data[:studio], @entry_data[:publisher])
    raise AgeRestricted if @entry_data[:genre] && @entry_data[:genre].any?(&:censored?) && censored_forbidden?

  rescue BadStatusError
    redirect_to send("#{klass.table_name}_url", url_params(status: nil)), status: 301

  rescue BadSeasonError
    redirect_to send("#{klass.table_name}_url", url_params(season: nil)), status: 301

  rescue ForceRedirect => e
    redirect_to e.url, status: 301
  end

  # меню каталога аниме/манги
  def menu
    @genres, @studios, @publishers = AniMangaAssociationsQuery.new.fetch
  end

private
  # класс текущего элемента
  def klass
    @klass ||= Object.const_get(params[:klass].to_s.camelize)
  end

  # окружение страниц
  def build_background
    @current_page = params_page
    @genres, @studios, @publishers = AniMangaAssociationsQuery.new.fetch

    all_data = {
      genre: @genres,
      publisher: @publishers,
      studio: @studios
    }
    @entry_data = {}

    if params[:type] =~ /[A-Z -]/
      raise ForceRedirect, self.send("#{klass.table_name}_url", url_params.merge(type: params[:type].downcase.sub(/ |-/, '_')))
    end
    [:genre, :studio, :publisher].each do |kind|
      if params[kind]
        all_param_ids = params[kind].split(',').map { |v| v.sub(/^!/, '').to_i }
        included_param_ids = params[kind].split(',').map(&:to_i).select {|v| v > 0 }

        all_entry_data = all_data[kind].select { |v| all_param_ids.include?(v.id) }
        @entry_data[kind] = all_data[kind].select { |v| included_param_ids.include?(v.id) }

        filter_klass = kind.to_s.capitalize.constantize
        all_param_ids.each do |id|
          if filter_klass::Merged.include? id
            raise ForceRedirect, self.send("#{klass.table_name}_url", url_params.merge(kind.to_sym => params[kind].gsub(%r{\b#{id}\b}, filter_klass::Merged[id].to_s)))
          end
        end

        next unless all_param_ids.size == 1 && params[kind].sub(/^!/, '') != all_entry_data.first.to_param
        raise ForceRedirect, self.send("#{klass.table_name}_url", url_params.merge(kind.to_sym => all_entry_data.first.to_param))
      end
    end
    build_page_title @entry_data
    build_page_description @entry_data
  end

  # постраничное разбитие коллекции
  def build_pagination_links(entries, total_pages)
    options = filtered_params

    if total_pages
      @total_pages = total_pages == 0 ? 1 : total_pages
    else
      @total_pages = entries.total_pages == 0 ? 1 : entries.total_pages
    end
    if @current_page == 1
      @prev_page = ''
    else
      @prev_page = url_for(options.merge(page: @current_page == 2 ? nil : (@current_page-1)))
    end

    if @current_page == @total_pages
      @next_page = ''
    else
      @next_page = @current_page < @total_pages ? url_for(options.merge(page: @current_page+1)) : ''
    end
  end

  # редирект для не автороизованных пользователей при ссылках на mylist, чтобы не падало с ошибкой
  def mylist_redirect_check
    if params.include?(:mylist) && !user_signed_in?
      params.except! :mylist
      raise ForceRedirect, url_for(filtered_params)
    end
  end

  # выборка из датасорса без пагинации
  def fetch_wo_pagination(query)
    entries = AniMangaQuery.new(klass, params).order(query)
      .decorate
      .to_a

    apply_in_list(entries)
      .group_by { |v| v.ova? || v.ona? ? 'OVA/ONA' : v.kind }
  end

  # выборка из датасорса с пагинацией
  def fetch_with_pagination(ds)
    entries = []
    # выборка id элементов с разбивкой по страницам
    unless params.include? :ids_with_sort
      entries = ds
        .select("#{klass.name.tableize}.id")
        .paginate(page: @current_page, per_page: entries_per_page)
      total_pages = entries.total_pages
    else
      entries = ds
        .where(id: params[:ids_with_sort].keys)
        .where.not(kind: [:special, :music])
        .select("#{klass.name.tableize}.id")
        .to_a
      total_pages = (entries.size * 1.0 / entries_per_page).ceil
      entries = entries
        .sort_by {|v| -params[:ids_with_sort][v.id] }
        .drop(entries_per_page*(@current_page-1))
        .take(entries_per_page)
    end

    entries = klass
      .where(id: entries.map(&:id))
      .includes(:genres)
      .includes(klass == Anime ? :studios : :publishers)

    # повторная сортировка полученной выборки
    if params[:ids_with_sort].present?
      entries = entries.sort_by {|v| -params[:ids_with_sort][v.id] }
    else
      entries = AniMangaQuery.new(klass, params).order(entries).to_a
    end
    build_pagination_links entries, total_pages

    apply_in_list(entries).map(&:decorate)
  end

  # присоединение параметра в списке ли пользователя элемент?
  def apply_in_list entries
    return entries unless user_signed_in? && current_user.preferences.mylist_in_catalog?

    rates = current_user.send("#{klass.name.downcase}_rates")
      .where(target_id: entries.map(&:id))
      .select(:target_id, :status)

    entries.each do |entry|
      entry.in_list = rates.find {|v| v.target_id == entry.id }.try(:status)
    end
  end

  # был ли запущен поиск, и найден ли при этом один элемент
  def one_found_redirect_check
    if params[:search] && @entries.count == 1 && @current_page == 1 && !json?
      raise ForceRedirect, url_for(@entries.first.kind_of?(ActiveRecord::Base) ? @entries.first : @entries.first[1][0])
    end
  end

  def params_page
    [(params[:page] || 1).to_i, 1].max
  end

  def build_page_title entry_data
    @page_title ||= klass.title_for params[:season], params[:type], entry_data[:genre], entry_data[:studio], entry_data[:publisher]
    @page_title.sub! 'Лучшие аниме', 'Аниме' if user_signed_in? && @page_title.is_a?(String)
  end

  def build_page_description entry_data
    order_name = case params[:order] || AniMangaQuery::DefaultOrder
      when 'name'
        'в алфавитном порядке'

      when 'popularity'
        'по популярности'

      when 'ranked'
        'по рейтингу'

      # TODO: удалить released_at после 01.05.2014
      when 'released_on', 'released_at'
        'по дате выхода'

      when 'id'
        'по дате добавления'
    end
    @description = klass.description_for params[:season], params[:type], entry_data[:genre], entry_data[:studio], entry_data[:publisher]

    order_word = if klass == Anime && @description[0].nil?
      'отсортированный'
    elsif klass == Anime || (params[:type] && !params[:type].include?(',') && params[:type].include?('ovel'))
      'отсортированных'
    else
      'отсортированной'
    end

    @title_notice = "На данной странице отображен #{@description[0].nil? ? '' : 'список'} #{@description[1]}, #{order_word} #{order_name}".sub(/,,|, ,| ,/, ',')

    #if entry_data[:genre].present? && entry_data[:genre].one? && entry_data[:genre].first.description.present? &&
        #entry_data[:studio].blank? && entry_data[:publisher].blank? &&
        #params[:season].blank? && params[:type].blank? && params[:status].blank? &&
        #params[:order].blank? && params[:rating].blank?
      #@title_notice = BbCodeFormatter.instance.format_description(entry_data[:genre].first.description, entry_data[:genre].first).gsub('div', 'p')
    #end
  end

  # число аниме/манги на странице
  def entries_per_page
    #user_signed_in? ? 24 : 12
    #user_signed_in? ? 40 : 20
    20
  end

  def filtered_params
    params.except :format, :exclude_ids, :ids_with_sort, :template, :is_adult, :exclude_ai_genres
  end
end
