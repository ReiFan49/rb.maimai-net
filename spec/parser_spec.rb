# Parser Spec is an optional test with provided pages from the developer itself.
# Actual files will not be provided publicly.

RSpec.describe MaimaiNet::Page, :aggregate_failures do
  def test_files(*files)
    fail ArgumentError, 'expected list of filenames, given empty' if files.empty?
    files.find do |fn|
      fn = fn + '.html' if File.extname(fn) == '' && File.exists?(fn + '.html')
      File.file?(fn)
    end&.yield_self do |fn|
      fn = fn + '.html' if File.extname(fn) == '' && File.exists?(fn + '.html')
      fn
    end
  end

  def load_page(parser, *files)
    fn = test_files(*files).yield_self do |fn|
           next fn unless fn.nil?
           files.last
         end

    path = Pathname(fn)
    skip 'is not file' unless path.file?

    expect(path).to exist
    expect(path).to be_file

    page = parser.parse(path.read)
    expect do page.data end.to_not raise_error

    if block_given? then
      yield page.data
    else
      page.data
    end
  end

  def flatten_hash_values(data)
    data&.values&.inject([], :concat)
  end

  it 'parse finale archive statistics', pending: !defined?(MaimaiNet::Model::FinaleArchive::Data) do
    expect(
      load_page(MaimaiNet::Page::FinaleArchive, 'pages/home_congratulations')
    ).to be_a(MaimaiNet::Model::FinaleArchive::Data)
  end

  it 'parse deluxe statistics', pending: !defined?(MaimaiNet::Model::PlayerData::Data) do
    expect(
      load_page(MaimaiNet::Page::PlayerData, 'pages/playerData')
    ).to be_a(MaimaiNet::Model::PlayerData::Data)
  end

  it 'parse recent photo upload', pending: !defined?(MaimaiNet::Model::PhotoUpload) do
    expect(
      load_page(MaimaiNet::Page::PhotoUpload, 'pages/playerData_photo')
    ).to all(be_a(MaimaiNet::Model::PhotoUpload))
  end

  it 'parse chartset record', pending: !defined?(MaimaiNet::Model::Record::Data) do
    expect(
      load_page(MaimaiNet::Page::ChartsetRecord, 'pages/record_musicDetail')
    ).to be_a(MaimaiNet::Model::Record::Data)
  end

  it 'parse recent gameplay session', pending: !defined?(MaimaiNet::Model::Result::TrackReference) do
    expect(
      load_page(MaimaiNet::Page::RecentTrack, 'pages/record')
    ).to all(be_a(MaimaiNet::Model::Result::TrackReference))
  end

  describe 'recent gameplay detail', pending: !defined?(MaimaiNet::Model::Result::Data) do
    it 'simple page' do
      data = load_page(MaimaiNet::Page::TrackResult, 'pages/record_playlogDetail')
      expect(data).to be_a(MaimaiNet::Model::Result::Data)
    end

    it 'with course info' do
      data = load_page(MaimaiNet::Page::TrackResult, 'pages/record_playlogDetail_course', 'pages/record_playlogDetail')
      expect(data).to be_a(MaimaiNet::Model::Result::Data)
      expect(data&.track).to_not be_nil
      expect(data&.track&.challenge).to be_a(MaimaiNet::Model::Result::Challenge)
    end

    it 'with otomodachi info' do
      data = load_page(MaimaiNet::Page::TrackResult, 'pages/record_playlogDetail_otomodachi', 'pages/record_playlogDetail')
      expect(data).to be_a(MaimaiNet::Model::Result::Data)
      expect(data&.rival).to be_a(MaimaiNet::Model::Result::RivalInfo)
    end
  end

  describe 'song list pages' do
    it 'genre grouping', pending: !defined?(MaimaiNet::Model::Record::InfoCategory) do
      expect(
        load_page(MaimaiNet::Page::MusicList, 'pages/record_musicGenre_search', &method(:flatten_hash_values))
      ).to all(be_a(MaimaiNet::Model::Record::InfoCategory))
    end

    it 'custom sort grouping', pending: !defined?(MaimaiNet::Model::Record::InfoCategory) do
      expect(
        load_page(MaimaiNet::Page::MusicList, 'pages/record_musicSort_search', &method(:flatten_hash_values))
      ).to all(be_a(MaimaiNet::Model::Record::InfoCategory))
    end

    it 'difficulty best grouping', pending: !defined?(MaimaiNet::Model::Record::InfoBest) do
      expect(
        load_page(MaimaiNet::Page::MusicList, 'pages/record_musicMybest_search')
      ).to all(be_a(MaimaiNet::Model::Record::InfoBest))
    end
  end
end
