class CalendarEntry < SimpleDelegator
  prepend ActiveCacher.instance

  instance_cache :last_news, :average_interval, :next_episode_start_at

  DEFAULT_TV_DURATION = 26
  EPISODES_FOR_AVERAGE_INTERVAL = 2

  def initialize anime
    raise ArgumentError, 'object must be decorated' unless anime.decorated?

    super anime
  end

  def average_interval
    if episodes_aired.zero?
      0
    else
      episode_news_topics.size >= EPISODES_FOR_AVERAGE_INTERVAL ?
        episode_average_interval :
        7.days
    end
  end

  def last_news
    episode_news_topics.max_by { |entry| entry.value.to_i }
  end

  def next_episode
    episodes_aired + 1
  end

  def next_episode_start_at
    next_episode_at
  end

  def next_episode_end_at
    next_episode_start_at + ((duration.zero? ? DEFAULT_TV_DURATION : duration) + 5).minutes
  end

private

  def episode_average_interval # rubocop:disable all
    times = []
    prior_time = episode_news_topics.first.created_at

    # учитываем только последние восемь записей
    episode_news_topics.reverse.take(8).reverse_each do |news|
      next if prior_time == news.created_at

      times << (news.created_at - prior_time).abs # /60/60/24
      prior_time = news.created_at
    end
    # считаем только по половине интервалов, отсекаем четверть самых коротких и четверть самых длинных
    # и берём срок не менее недели
    interval =
      if times.size >= 4
        times.sort.slice(times.size / 4, times.size).take(times.size / 2).sum / (times.size / 2)
      else
        times.sum / times.size
      end

    [7.days, interval].max
  end

  def broadcast_at
    return unless super

    if super > 1.hour.ago
      super
    elsif last_news && super - last_news.created_at < 14.days
      super + 1.week
    end
  end

  def episode_news_topics
    super.select { |v| v.locale == 'ru' }
  end
end
