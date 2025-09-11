RSpec.describe MaimaiNet do
  before :context do
    @conn = MaimaiNet::Client::AsiaRegion.new('username', 'password')
  end

  subject do @conn end

  describe 'session management' do
    it 'can login' do
      is_expected.to respond_to(:home)
    end

    it 'can logout' do
      is_expected.to respond_to(:logout)
    end
  end

  describe 'statistics page' do
    it 'can load maimai FiNALE statistics' do
      is_expected.to respond_to(:finale_archive)
    end

    it 'can load maimai DX statistics' do
      is_expected.to respond_to(:player_data)
    end
  end

  describe 'recent gameplay data' do
    it 'can load recent gameplay session info' do
      is_expected.to respond_to(:recent_plays)
    end

    describe 'extended gameplay result' do
      subject do MaimaiNet::Model::Result::Data.members end

      it 'has challenge support', :planned do
        is_expected.to include(:challenge)
      end

      it 'has tour member list support' do
        is_expected.to include(:members)
      end

      it 'has otomodachi support' do
        is_expected.to include(:rival)
      end

      it 'has full sync support', :planned do
        is_expected.to include(:friends)
      end
    end

    it 'can load detailed recent gameplay info' do
      is_expected.to respond_to(:recent_play_info).with(1).arguments
    end

    it 'can load detailed recent gameplay session info' do
      is_expected.to respond_to(:recent_play_details)
    end

    it 'can load recent uploads' do
      is_expected.to respond_to(:photo_album)
    end
  end

  describe 'grouped song list per category' do
    it 'can group by genre' do
      is_expected.to respond_to(:song_list_by_genre).with_keywords(:genres, :diffs)
      is_expected.to_not respond_to(:song_list_by_genre).with_keywords(:genre)
      is_expected.to_not respond_to(:song_list_by_genre).with_keywords(:diff)
    end

    it 'can group by song title' do
      is_expected.to respond_to(:song_list_by_title).with_keywords(:characters, :diffs)
      is_expected.to_not respond_to(:song_list_by_title).with_keywords(:character)
      is_expected.to_not respond_to(:song_list_by_title).with_keywords(:diff)
    end

    it 'can group by level' do
      is_expected.to respond_to(:song_list_by_level).with_keywords(:levels)
      is_expected.to_not respond_to(:song_list_by_level).with_keywords(:level)
      is_expected.to_not respond_to(:song_list_by_level).with_keywords(:diff)
    end

    it 'can group by version' do
      is_expected.to respond_to(:song_list_by_version).with_keywords(:versions, :diffs)
      is_expected.to_not respond_to(:song_list_by_version).with_keywords(:version)
      is_expected.to_not respond_to(:song_list_by_version).with_keywords(:diff)
    end

    xit 'can custom sort', :planned do
      is_expected.to respond_to(:song_list_by_custom)
        .with_keywords(:genres, :characters, :levels, :versions, :diffs, :sort)
    end

    xit 'can check difficulty best', priority: :low
  end

  it 'can load best score of a set' do
    is_expected.to respond_to(:music_record_info).with(1).arguments
  end

  it 'has friend support'

  describe 'user configuration', :planned do
    it 'can fetch configuration', :aggregate_failures
    it 'can update favorites'
    it 'can update configuration'
  end

  it 'achievement rate chart list', priority: :low

  it 'knows maintenance time' do
    if defined?(Timecop) then
      period = @conn.maintenance_period
      Timecop.freeze(period.begin) do
        expect(period).to include(Time.now)
      end
    else
      pending 'need mockable time gem installed'
      expect do require 'timecop' end.to_not raise_error
    end
  end

  {}.tap do |meta|
    util_methods = MaimaiNet::Util.instance_methods(false)
    meta[:skip] = 'may need namespace-wide utilities' if util_methods.empty?
    it 'has namespace-wide utilities', **meta do
      expect(util_methods).to_not be_empty
    end
  end
end
