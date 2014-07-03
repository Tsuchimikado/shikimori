require 'spec_helper'

describe NotificationsService do
  let(:service) { NotificationsService.instance }
  let(:user) { create :user }
  let(:friend) { create :user, notifications: notifiactions }
  let(:old_nickname) { 'old_nick' }
  let(:new_nickname) { 'new_nick' }

  subject(:notify) { service.nickname_change user, friend, old_nickname, new_nickname }

  context :disabled_notifications do
    let(:notifiactions) { User::DEFAULT_NOTIFICATIONS - User::NICKNAME_CHANGE_NOTIFICATIONS }
    it { should be nil }
    it { expect{subject}.to_not change(Message, :count) }
  end

  context :allowed_notifications do
    before { BotsService.stub(:get_poster).and_return bot }
    let(:notifiactions) { User::DEFAULT_NOTIFICATIONS  }
    let(:bot) { create :user }

    it { should be_persisted }
    its(:from) { should eq bot }
    its(:to) { should eq friend }
    its(:body) { should include old_nickname }
    its(:body) { should include new_nickname }
    it { expect{subject}.to change(Message, :count).by 1 }
    it 'ignores antispam' do
      expect {
        service.nickname_change user, friend, old_nickname, new_nickname
        service.nickname_change user, friend, old_nickname, new_nickname
      }.to change(Message, :count).by 2
    end
  end
end
