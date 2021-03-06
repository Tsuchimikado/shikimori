class Clubs::ClubImagesController < ShikimoriController
  load_and_authorize_resource :club
  load_and_authorize_resource only: [:destroy]

  # rubocop:disable AbcSize
  def create
    if request.xhr?
      @resource = create_image params[:image]

      render(
        json: ClubImageSerializer.new(@resource, scope: view_context).to_json
      )

    elsif params[:images]
      params[:images].each { |image| create_image image }
      redirect_to club_url(@club), notice: i18n_t('image_uploaded')

    else
      redirect_to club_url(@club), alert: i18n_t('no_images_uploaded')
    end
  end
  # rubocop:enable AbcSize

  def destroy
    @resource.destroy!
    render json: { notice: i18n_t('image_deleted') }
  end

private

  def create_image uploaded_file
    image = ClubImage.new(
      club: @club,
      user: current_user,
      image: uploaded_file
    )
    authorize! :create, image
    image.save!
    image
  end
end
