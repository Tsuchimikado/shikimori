class UsersController < ShikimoriController
  respond_to :json, :html, only: :index

  LIMIT = 15
  THRESHOLDS = [25, 50, 100, 175, 350]

  # список всех пользователей
  def index
    @page = [params[:page].to_i, 1].max
    @limit = LIMIT

    page_title i18n_i('User', :other)
    @collection = Users::Query.fetch
      .search(params[:search])
      .paginate(@page, @limit)
      .transform(&:decorate)

      # if params[:search].present?
        # UsersQuery.new(params).search
      # else
        # User
          # .where.not(id: 1)
          # .where.not(last_online_at: nil)
          # .order('(case when last_online_at > coalesce(current_sign_in_at, now()::date - 365)
            # then last_online_at else coalesce(current_sign_in_at, now()::date - 365) end) desc')
      # end
    # end

    # unless params[:search]
      # @collection.sort_by!(&:last_online_at)
      # @collection.reverse!
    # end

    # @collection.map!(&:decorate) if @collection
  end

  def similar
    @page = [params[:page].to_i, 1].max
    @limit = LIMIT
    @threshold = params[:threshold].to_i
    @klass = params[:klass] == Manga.name.downcase ? Manga : Anime

    unless THRESHOLDS.include?(@threshold)
      redirect_to similar_users_path(url_params(threshold: THRESHOLDS[2]))
      return
    end

    page_title i18n_t 'similar_users'
    @similar_ids = SimilarUsersFetcher.new(user_signed_in? ? current_user.object : nil, @klass, @threshold).fetch

    if @similar_ids
      ids = @similar_ids
        .drop(@limit * (@page - 1))
        .take(@limit)

      @collection = User.where(id: ids).sort_by {|v| ids.index v.id }
    end

    @add_postloader = @similar_ids && @similar_ids.any? && @page * @limit < SimilarUsersService::MAXIMUM_RESULTS
    @collection.map!(&:decorate) if @collection
  end

  # автодополнение
  def autocomplete
    @collection = UsersQuery.new(params).complete
  end
end
