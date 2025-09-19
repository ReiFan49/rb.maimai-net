require 'maimai_net/model'

require 'nokogiri'

module MaimaiNet
  module Page
    class Base
      include ModuleExt
      include ModuleExt::MethodCache

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
    require 'maimai_net/page-track_result_helper'

    class PlayerData < Base
      STAT_KEYS = %i(
        count_sssp count_sss
        count_ssp  count_ss
        count_sp   count_s
        count_clear
        count_dx5
        count_dx4  count_dx3
        count_dx2  count_dx1
        count_max  count_ap
        count_gfc  count_fc
        count_fdx2 count_fdx1
        count_fs2  count_fs1  count_sync_play
      ).freeze

      STAT_FIELDS = {
        ranks: [
          %i(count_s count_sp count_ss count_ssp count_sss count_sssp),
          %i(s s+ ss ss+ sss sss+),
        ],
        dx_ranks: [
          Array.new(5) do |i| :"count_dx#{i.succ}" end,
          Array.new(5) do |i| i.succ end,
        ],
        flags: [
          %i(count_fc count_gfc count_ap count_max),
          %i(fc gfc ap max),
        ],
        sync_flags: [
          %i(count_sync_play count_fs1 count_fs2 count_fdx1 count_fdx2),
          %i(play full_sync_miss full_sync_match full_deluxe_miss full_deluxe_match),
        ],
      }.freeze

      def initialize_extension
        super

        @gameplay_block = @root.at_css('.see_through_block:nth-of-type(1)')
        @player_block = @gameplay_block.at_css('.basic_block')
      end

      helper_method :data do
        user_count_version_plays, user_count_series_plays = scan_int(strip(@gameplay_block.at_css('> .basic_block + .clearfix + div')))
        deluxe_web_id = int(@gameplay_block.at_css('form[action$="/playerData/"] button[name=diff][value]:has(.diffbtn_selected)')['value'])
        diff = Difficulty({deluxe_web_id: deluxe_web_id})

        raw_stat = STAT_KEYS.zip(PlayerDataHelper.process(@gameplay_block)).to_h
        diff_stat = {}
        diff_stat[:clears] = raw_stat[:count_clear]
        STAT_FIELDS.each do |k, (source, target)|
          diff_stat[k] = target.zip(raw_stat.values_at(*source)).to_h
        end
        user_diff_stat = {diff.abbrev => Model::PlayerData::DifficultyStatistic.new(**diff_stat)}

        Model::PlayerData::Data.new(
          plate: Model::PlayerData::InfoPlate.new(
            info: Model::PlayerCommon::Info.new(
              name: strip(@player_block.at_css('.name_block')),
              title: strip(@player_block.at_css('.trophy_block')),
              grade: src(@player_block.at_css('> div > .clearfix ~ img:nth-of-type(1)')),
            ),
            decoration: Model::PlayerData::Decoration.new(
              icon: URI(src(@player_block.at_css('> img:nth-of-type(1)'))),
            ),
            extended: Model::PlayerData::ExtendedInfo.new(
              rating: get_int(strip(@player_block.at_css('.rating_block'))),
              class_grade: src(@player_block.at_css('> div > .clearfix ~ img:nth-of-type(2)')),
              partner_star_total: get_int(strip(@player_block.at_css('> div > .clearfix ~ div:nth-of-type(1)'))),
            ),
          ),
          statistics: user_diff_stat,
        )
      end
    end

    class PhotoUpload < Base
      helper_method :data do
        images = @root.css('.container ~ div')
        images.map do |elm|
          elm = elm.at_css('> div')

          chart_type = Pathname(src(elm.at_css('> .music_kind_icon'))).sub_ext('').basename
          difficulty = Difficulty(Pathname(src(elm.at_css('> img:nth-of-type(2)'))).sub_ext('').sub('diff_', '').basename)

          Model::PhotoUpload.new(
            info: Model::Chart::InfoLite.new(
              title: strip(elm.at_css('> div:not(.clearfix):nth-of-type(2)')),
              type: chart_type.to_s,
              difficulty: difficulty.id,
            ),
            url: URI(src(elm.at_css('> img:nth-of-type(3)'))),
            location: strip(elm.at_css('> div:not(.clearfix):nth-of-type(4)')),
            time: Time.strptime(
              strip(elm.at_css('> div:not(.clearfix):nth-of-type(1)')) + ' +09:00',
              '%Y/%m/%d %H:%M %z',
              Time.now.localtime(32400),
            ),
          )
        end
      end
    end

    class ChartsetRecord < Base
      def initialize_extension
        super

        @summary_block = @root.at_css('.basic_block')
      end

      helper_method :data do
        song_info_elm = @summary_block.at_css('> div:nth-of-type(1)')

        song_jacket = URI(src(@summary_block.at_css('> img:nth-of-type(1)')))
        set_type = Pathname(src(song_info_elm.at_css('> div:nth-of-type(1) > img'))).sub_ext('').sub(/.+_/, '').basename.to_s
        song_genre = strip(song_info_elm.at_css('> div:nth-of-type(1)'))
        song_name = strip(song_info_elm.at_css('> div:nth-of-type(2)'))
        song_artist = strip(song_info_elm.at_css('> div:nth-of-type(3)'))

        song_info = Model::Chart::Song.new(
          title:  song_name,
          artist: song_artist,
          genre:  song_genre,
          jacket: song_jacket,
        )

        chart_records = {}
        difficulty_data = {}
        info_blocks = @summary_block.css('table > tbody > tr:has(.music_lv_back):has(form input[type=hidden][name=diff])')
        chart_score_blocks = @summary_block.css('~ div:has(~ img)')

        info_blocks.each do |info_block|
          level_text = strip(info_block.at_css('.music_lv_back'))
          form_block = info_block.at_css('form')
          form_inputs = form_block.css('input[name][type=hidden]').map do |elm|
            [elm['name'].to_sym, elm['value']]
          end.to_h
          difficulty = Difficulty(deluxe_web_id: form_inputs[:diff].to_i)
          difficulty_data[difficulty.abbrev] ||= {}
          difficulty_data[difficulty.abbrev].store(:info, Model::Chart::Info.new(
            web_id:     Model::WebID.parse(form_inputs[:idx]),
            title:      song_name,
            type:       set_type,
            difficulty: difficulty.id,
            level_text: level_text,
          ))
        end

        chart_score_blocks.each do |chart_score_block|
          difficulty = Difficulty(Pathname(src(chart_score_block.at_css('> img:nth-of-type(1)'))).sub_ext('').sub(/.+_/, '').basename)
          chart_type = Pathname(src(chart_score_block.at_css('> img:nth-of-type(2)')))&.sub_ext('')&.sub(/.+_/, '')&.basename&.to_s or set_type
          clearfixes = chart_score_block.css('.clearfix')

          chart_record_block = clearfixes[0].at_css('~ div:nth-of-type(2)')
          record_grade, record_flag, record_sync_flag = chart_record_block.css('> img').map do |elm|
            value = Pathname(URI(src(elm)).path).sub_ext('')&.sub(/.+_/, '')&.basename.to_s
            case value
            when 'back'; nil
            when *MaimaiNet::AchievementFlag::RECORD.values; MaimaiNet::AchievementFlag.new(record_key: value)
            else value.to_sym
            end
          end
          last_played_date, total_play_count = chart_record_block.css('table tr td:nth-of-type(2)').zip([
            ->(content){Time.strptime(content + ' +09:00', '%Y/%m/%d %H:%M %z')},
            method(:int),
          ]).map do |elm, block|
            block.call(strip(elm))
          end

          chart_best_block = clearfixes[1].at_css('~ div')
          chart_score = strip(chart_best_block.at_css('.music_score_block:nth-of-type(1)')).to_f
          chart_deluxe_scores = scan_int(strip(chart_best_block.at_css('.music_score_block:nth-of-type(2)')))
          chart_deluxe_grade_elm = chart_best_block.at_css('.music_score_block:nth-of-type(2) img:nth-child(2)')
          record_deluxe_grade = chart_deluxe_grade_elm ?
            Pathname(src(chart_deluxe_grade_elm))&.sub_ext('')&.sub(/.+_/, '')&.basename&.to_s.to_i :
            0

          difficulty_data[difficulty.abbrev].tap do |d|
            d[:record] = Model::Record::Score.new(
              web_id: d[:info].web_id,
              score: chart_score,
              deluxe_score: Model::Result::Progress.new(%i(value max).zip(chart_deluxe_scores).to_h),
              grade: record_grade,
              deluxe_grade: record_deluxe_grade,
              flags: [record_flag, record_sync_flag].compact.map(&:to_sym),
            )
            d[:history] = Model::Record::History.new(
              play_count: total_play_count,
              last_played: last_played_date,
            )
          end
        end

        difficulty_data.each do |abbrev, data|
          difficulty = Difficulty(abbrev: abbrev)

          chart_records[abbrev] = Model::Record::ChartRecord.new(**data)
        end

        Model::Record::Data.new(
          info: song_info,
          charts: chart_records,
        )
      end
    end

    class TrackResult < Base
      def initialize_extension
        super

        start_anchor = @root.at_css('img.title')
        @otomodachi_block = start_anchor.at_css('~ div#vsUser > :first-child')
        @score_block = start_anchor.at_css('~ div:not(#vsUser):nth-of-type(1)')
        @breakdown_block = start_anchor.at_css('~ div:not(#vsUser):nth-of-type(2)')
      end

      helper_method :data do
        result_breakdown = @breakdown_block.css('table.playlog_notes_detail tr:not(:first-child)').map do |row|
          key = Pathname(URI(src(row.at_css('th img'))).path).sub_ext('').basename.to_s.to_sym
          values = Model::Result::Judgment.new(**Model::Result::Judgment.members.zip(
            row.css('td').map(&method(:strip)).map(&method(:get_int))
          ).to_h)

          [key, values]
        end.to_h
        result_offset_breakdown = @breakdown_block.css('.playlog_fl_block > div').map do |elm|
          get_int(strip(elm))
        end
        result_rating_after = int(strip(@breakdown_block.at_css('.playlog_rating_detail_block > div:nth-of-type(1) .rating_block')))
        result_rating_delta = int(strip(@breakdown_block.at_css('.playlog_rating_detail_block > div:nth-of-type(2)')))
        result_combos, result_sync_scores = @breakdown_block.css('.playlog_score_block').map do |elm|
          scan_int(strip(elm)).tap do |ary| ary.fill(0, ary.size...2) end
        end

        result_tour_members = @breakdown_block.css('.playlog_chara_container').map do |chara_block|
          Model::Result::TourMember.new(
            icon: URI(src(chara_block.at_css('.chara_cycle_img'))),
            grade: get_int(strip(chara_block.at_css('.collection_chara_awakening_block_txt'))),
            level: get_int(strip(chara_block.at_css('.playlog_chara_lv_block'))),
          )
        end

        result_otomodachi_rival = nil
        unless @otomodachi_block.nil? then
          rival_name   = strip(@otomodachi_block.at_css('> span > div').children[0])
          rival_score  = strip(@otomodachi_block.at_css('> span > div > span')).to_f
          rival_rating = int(strip(@otomodachi_block.at_css('> div .rating_block')))

          result_otomodachi_rival = Model::Result::RivalInfo.new(
            player: Model::PlayerData::Lite.new(
              name: rival_name,
              rating: rival_rating,
            ),
            score: rival_score,
          )
        end

        chart_web_id = Model::WebID.parse(@root.at_css('form[action$="/record/musicDetail/"] input[name=idx]')['value'])

        Model::Result::Data.new(
          track: TrackResultHelper.process(
            @score_block,
            web_id: chart_web_id,
            result_combo: result_combos,
            result_sync_score: result_sync_scores,
          ),
          breakdown: result_breakdown,
          timing: Model::Result::Offset.new(**Model::Result::Offset.members.zip(result_offset_breakdown).to_h),
          members: result_tour_members,
          rival: result_otomodachi_rival,
        )
      end
    end

    class RecentTrack < Base
      helper_method :data do
        track_blocks = @root.css('img.title ~ div')

        track_blocks.map do |elm|
          ref_web_id = Model::Result::ReferenceWebID.parse(elm.at_css('form input[type=hidden][name=idx]')['value'])
          Model::Result::TrackReference.new(
            track: TrackResultHelper.process(elm),
            ref_web_id: ref_web_id,
          )
        end.sort_by do |track_ref| track_ref.ref_web_id.time end
      end
    end

    class MusicList < Base
      helper_method :data do
        track_group_blocks = @root.css('.screw_block')
        track_segmented_blocks = {}
        current_group = nil

        if track_group_blocks.empty? then
          track_segmented_blocks[current_group] = @root.css('div:has(> form[action$="/musicDetail/"] input[name=idx])')
        else
          @root.css('.see_through_block ~ div').each do |elm|
            if elm.classes.include? 'screw_block' then
              current_group = elm.content
              next
            end

            track_segmented_blocks[current_group] ||= Nokogiri::XML::NodeSet.new(@document)
            track_segmented_blocks[current_group] << elm
          end
        end

        result = track_segmented_blocks.transform_values do |elm_group|
          elm_group.map do |elm|
            chart_info = Model::Chart::Info.new(
              web_id: Model::WebID.parse(elm.at_css('input[name=idx][type=hidden]')['value']),
              title: elm.at_css('.music_name_block').content,
              type: Pathname(URI(src(elm.at_css('.music_kind_icon'))).path).sub_ext('').sub(/.+_/, '').basename.to_s,
              difficulty: Difficulty(Pathname(URI(src(elm.at_css('form > img:nth-of-type(1)'))).path).sub_ext('').sub(/.+_/, '').basename.to_s).id,
              level_text: elm.at_css('.music_lv_block').content,
            )

            score_info = nil

            if !elm.at_css('.music_score_block:nth-of-type(1) > div').nil? then
              if elm.at_css('.music_score_block > div > img').nil? then
                # musicMybest page
                Model::Record::InfoBest.new(
                  info: chart_info,
                  play_count: get_int(strip(elm.at_css('.music_score_block'))),
                )
              else
                # ratingTargetMusic page
                best_grade = Pathname(URI(src(elm.at_css('.music_score_block:nth-of-type(1) > div > img'))).path).sub_ext('').sub(/.+_/, '').basename.to_s.to_sym
                score_info = Model::Result::ScoreOnly.new(
                  score: strip(elm.at_css('.music_score_block:nth-of-type(1)')).to_f,
                  grade: best_grade,
                )

                Model::Record::InfoRating.new(
                  info: chart_info,
                  score: score_info,
                )
              end
            else
              # music<Category> page
              if !elm.at_css('.music_score_block').nil? then
                best_deluxe_score = scan_int(strip(elm.at_css('.music_score_block:nth-of-type(2)')))
                flairs = elm.css('.music_score_block ~ img:has(~ .clearfix)').map do |img|
                  Pathname(URI(src(img)).path).sub_ext('').sub(/.+_/, '').basename.to_s.to_sym.yield_self do |value|
                    value == :back ? nil : value
                  end
                end
                *record_flags, best_grade = flairs
                record_flags.compact!
                record_flags.map! &:to_s
                record_flags.map! do |key| MaimaiNet::AchievementFlag.new(record_key: key) end
                score_info = Model::Result::ScoreLite.new(
                  score: strip(elm.at_css('.music_score_block:nth-of-type(1)')).to_f,
                  deluxe_score: Model::Result::Progress.new(**%i(value max).zip(best_deluxe_score).to_h),
                  grade: best_grade,
                  flags: record_flags.map(&:to_sym),
                )
              end

              Model::Record::InfoCategory.new(
                info: chart_info,
                score: score_info,
              )
            end
          end
        end

        if result.size == 1 && result.key?(nil) then
          result[nil]
        else
          result
        end
      end
    end

    class UserOption < Base
      helper_method :data do
        settings = {}

        @root.css('select').each do |group_elm|
          name = group_elm['name'].dup.freeze
          selected = nil
          option = group_elm.css('option').map do |choice_elm|
            selected = choice_elm['value'].to_i if choice_elm['selected']
            choice = MaimaiNet::UserOption::Choice.new(
              name,
              choice_elm['value'].to_i,
              choice_elm.content.dup,
            )

            [choice.value, choice]
          end.to_h

          option = option.values if option.keys.each_cons(2).all? do |x, y| (y - x).pred.zero? end
          option = MaimaiNet::UserOption::Option.new(
            name,
            option,
            option[selected],
          )

          settings[name.to_sym] = option
        end

        settings
      end
    end

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
          %i(s s+ ss ss+ sss max),
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
          diff = Difficulty(key)

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
            icon:         URI(src(@player_block.at_css('.finale_icon'))),
            player_frame: URI(user_block_image),
            nameplate:    URI(src(@player_block.at_css('.finale_nameplate'))),
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
