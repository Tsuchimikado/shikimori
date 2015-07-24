class Api::V1::NicknameChangesController < Api::V1::ApiController
  def cleanup
    current_user.nickname_changes.update_all is_deleted: true
    render json: { notice: "Ваша история имён очищена" }
  end
end
