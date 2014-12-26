describe PagesController do
  let(:user) { create :user }

  describe 'auth_form' do
    before { get :auth_form }
    it { should respond_with :success }
  end

  describe 'ongoings' do
    before do
      create :ongoing_anime
      create :anons_anime
      create :topic, :with_section, id: 94879
      get :ongoings
    end

    it { should respond_with :success }

    describe 'signed_in user' do
      before do
        sign_in user
        get :ongoings
      end

      it { should respond_with :success }
    end
  end

  describe 'news' do
    let(:section) { create :section, permalink: 'a' }

    context 'common' do
      before do
        create :topic, broadcast: true, section: section
        create :topic, broadcast: true, section: section
        get :news, format: 'rss'
      end

      it { should respond_with :success }
      it { should respond_with_content_type :rss }
      it { expect(assigns(:topics).size).to eq(2) }
    end

    context 'anime' do
      before do
        create :anime_news, generated: false, section: section, linked: create(:anime), action: AnimeHistoryAction::Anons
        create :anime_news, generated: false, section: section, linked: create(:anime), action: AnimeHistoryAction::Anons
        get :news, kind: 'anime', format: 'rss'
      end

      it { should respond_with :success }
      it { should respond_with_content_type :rss }
      it { expect(assigns(:topics).size).to eq(2) }
    end
  end

  describe 'user_agreement' do
    before { get :user_agreement }
    it { should respond_with :success }
  end

  describe 'pages404' do
    before { get :page404 }
    it { should respond_with 404 }
  end

  describe 'pages503' do
    before { get :page503 }
    it { should respond_with 503 }
  end

  describe 'feedback' do
    before do
      create :user, id: 1
      create :user, id: User::GuestID
      get :feedback
    end

    it { should respond_with :success }
  end

  describe 'user_agent' do
    before { get :user_agent }
    it { should respond_with :success }
  end

  describe 'admin_panel' do
    context 'guest' do
      before { get :admin_panel }
      it { should respond_with 403 }
    end

    context 'user' do
      before do
        sign_in user
        get :admin_panel
      end

      it { should respond_with 403 }
    end

    context 'admin' do
      before do
        allow_any_instance_of(PagesController).to receive(:`).and_return ''
        allow($redis).to receive(:info).and_return('db0' => '=,')
        sign_in create :user, id: 1
        get :admin_panel
      end

      it { should respond_with :success }
    end
  end

  describe 'about' do
    before { get :user_agent }
    it { should respond_with :success }
  end

  describe 'welcome_gallery' do
    before { get :user_agent }
    it { should respond_with :success }
  end

  describe 'tableau' do
    before { get :tableau }

    it { should respond_with :success }
    it { expect(response.content_type).to eq 'application/json' }
  end
end
