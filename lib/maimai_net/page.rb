require 'maimai_net/model'

require 'nokogiri'

module MaimaiNet
  module Page
    class Base
      include CoreExt
      include CoreExt::MethodCache

      cache_method :data

      # @param document [Nokogiri::HTML::Document]
      # @raise [ArgumentError] invalid document structure
      # @see #validate!
      def initialize(document)
        @document = document
        @root = document.at_css('.main_wrapper')

        initialize_extension
        validate!
      end

      # @abstract extends variable initialization of the class.
      # @return [void]
      def initialize_extension
      end

      # validates document structure
      # @raise [ArgumentError] invalid document structure
      # @return [void]
      def validate!
        fail ArgumentError, 'provided document is not a valid maimai-net format' if @root.nil?
      end

      class << self
        # @param content [String] provided page content
        # @return [Page::Base]
        def parse(content)
          doc_class = Nokogiri::HTML
          doc_class = Nokogiri::HTML5 if defined?(Nokogiri::HTML5) && %r{^\s*<!DOCTYPE\s+html>\s?}i.match?(content)
          new(doc_class.parse(content))
        end
      end

      inspect_permit_expression do |value|
      	!(Nokogiri::XML::Node === value)
      end

      protected :initialize_extension
    end

    require 'maimai_net/page-html_helper'
    require 'maimai_net/page-player_data_helper'

    class FinaleArchive < Base
      STAT_KEYS = %i(
        count_clear
        count_s    count_sp
        count_ss   count_ssp
        count_sss  count_max
        count_fc   count_gfc count_ap
        count_sync_play
        count_mf count_tmf count_sync_max
      ).freeze

      STAT_FIELDS = {
        ranks: [
          %i(count_s count_sp count_ss count_ssp count_sss count_max),
          %i(s sp ss ssp sss max),
        ],
        flags: [
          %i(count_fc count_gfc count_ap),
          %i(fc gfc ap),
        ],
        sync_flags: [
          %i(count_sync_play count_sync_max),
          %i(play max),
        ],
        multi_flags: [
          %i(count_mf count_tmf),
          %i(max_fever strong_max_fever),
        ]
      }.freeze


      # @return [void]
      def initialize_extension
        super

        @root = @root.at_css('.finale_area')
        @gameplay_block = @root.at_css('.see_through_block:nth-of-type(1)')
        @collection_block = @root.at_css('.see_through_block:nth-of-type(2)')
        @player_block = @root.at_css('.basic_block')
      end

      helper_method :data do
        user_block_styles = Page::parse_style(@player_block.at_css('.finale_user_block'))
        user_block_image = user_block_styles['background-image'][4...-1] rescue nil

        user_rating_str = strip(@player_block.at_css('.finale_rating'))
        user_rating_current, user_rating_max = user_rating_str.scan(/[1-9]*[0-9]\.[0-9]+/).map &:to_f
        user_currency = strip(@player_block.at_css('.finale_point_block')).scan(/\d+/).map(&method(:int))
        user_currency.fill(0, user_currency.size...3)

        user_count_version_plays, user_count_sync_plays,
          user_count_versus_wins, user_count_sync_amount = @gameplay_block.css('table td')
            .map(&method(:strip)).map(&method(:get_int))

        user_diff_stat = {}
        @gameplay_block.css('div.finale_musiccount_block').each do |difficulty_block|
          key = difficulty_block.attribute('id').value.slice(0...-4).to_sym
          diff = MaimaiNet.Difficulty(key)

          diff_stat = {}
          raw_stat = {}
          raw_stat[:total_score] = get_int(strip(difficulty_block.at_css('div:nth-child(1)')))
          raw_stat.update STAT_KEYS.zip(PlayerDataHelper.process(difficulty_block)).to_h

          diff_stat[:total_score] = raw_stat[:total_score]
          diff_stat[:clears] = raw_stat[:count_clear]
          STAT_FIELDS.each do |k, (source, target)|
            diff_stat[k] = target.zip(raw_stat.values_at(*source)).to_h
          end

          user_diff_stat[diff.abbrev] = Model::FinaleArchive::DifficultyStatistic.new(**diff_stat)
        end

        user_collection_count = int(strip(@collection_block.at_css('div:nth-child(1)')))

        Model::FinaleArchive::Data.new(
          info: Model::PlayerCommon::Info.new(
            name:  strip(@player_block.at_css('.finale_username')),
            title: strip(@player_block.at_css('.finale_trophy_inner_block')),
            grade: src(@player_block.at_css('.finale_grade')),
          ),
          decoration: Model::FinaleArchive::Decoration.new(
            icon:         src(@player_block.at_css('.finale_icon')),
            player_frame: user_block_image,
            nameplate:    src(@player_block.at_css('.finale_nameplate')),
          ),
          extended: Model::FinaleArchive::ExtendedInfo.new(
            rating:         user_rating_current,
            rating_highest: user_rating_max,

            region_count:   int(strip(@player_block.at_css('.finale_region_block'))),

            currency:            Model::FinaleArchive::Currency.new(
              amount: user_currency[0],
              piece:  user_currency[1],
              parts:  user_currency[2],
            ),
            partner_level_total: int(strip(@player_block.at_css('.finale_totallv')).scan(/\d+/).first),
          ),
          statistics: user_diff_stat,
        )
      end
    end

    class << self
      def parse_style(element)
        case element
        when NilClass
          return {}
        when Nokogiri::XML::Element
        else
          fail TypeError, "expected HTML Node, given #{element.class}"
        end

        element['style']&.split(/\s*;\s*/)&.map do |line|
          line.split(/\s*:\s*/, 2)
        end.to_h
      end
    end

    require 'maimai_net/page-debug'
  end
end
