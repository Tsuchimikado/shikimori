class VersionsView < ViewObjectBase
  instance_cache :moderators, :pending, :processed, :processed_query
  per_page_limit 25

  def processed
    processed_query.first.map(&:decorate)
  end

  def postloader?
    processed_query.second
  end

  def pending
    Moderation::VersionsItemTypeQuery.call(h.params[:type])
      .includes(:user, :moderator)
      .where(state: :pending)
      .order(:created_at)
      .limit(per_page_limit)
      .decorate
  end

  def next_page_url
    h.moderations_versions_url(
      page: page + 1,
      type: h.params[:type],
      created_on: h.params[:created_on]
    )
  end

  def moderators
    User
      .where("roles && '{version_moderator}'")
      .where.not(id: User::MORR_ID)
      .sort_by { |v| v.nickname.downcase }
  end

private

  def processed_query
    Moderation::ProcessedVersionsQuery
      .new(h.params[:type], h.params[:created_on])
      .postload(page, per_page_limit)
  end
end
