module MaimaiNet
  module Page
    module TrackResultHelper
      using IncludeAutoConstant
      def self.process(
        elm,
        web_id: MaimaiNet::Model::WebID::DUMMY,
        result_combo: nil,
        result_sync_score: nil
      )
        HelperBlock.send(:new, nil).instance_exec do
          header_block = elm.at_css('.playlog_top_container')
          difficulty = get_chart_difficulty_from(header_block.at_css('img.playlog_diff'))
          utage_variant = get_chart_variant_from(header_block.at_css('.playlog_music_kind_icon_utage'))

          dx_container_classes = MaimaiNet::Difficulty::DELUXE.select do |k, v| v.positive? end
            .keys.map do |k| ".playlog_#{k}_container" end
          # info_block = elm.at_css(*dx_container_classes)
          info_block = elm.at_css(".playlog_#{difficulty.key}_container")
          chart_header_block = info_block.at_css('.basic_block')
          result_block = info_block.at_css('.basic_block ~ div:nth-of-type(1)')

          track_order = get_fullint(strip(header_block.at_css('div.sub_title > span:nth-of-type(1)')))
          play_time = jst_from(header_block.at_css('div.sub_title > span:nth-of-type(2)'))
          song_name = strip(chart_header_block.children.last)
          chart_level = get_chart_level_text_from(chart_header_block.at_css('div:nth-of-type(1)'))
          song_jacket = src(result_block.at_css('img.music_img'))
          chart_type  = get_chart_type_from(result_block.at_css('img.playlog_music_kind_icon'))

          result_score = strip(result_block.at_css('.playlog_achievement_txt')).to_f
          result_deluxe_scores = scan_int(strip(result_block.at_css('.playlog_result_innerblock .playlog_score_block div:nth-of-type(1)')))
          result_grade = subpath_from(result_block.at_css('.playlog_scorerank')).to_sym
          result_flags = result_block.css('.playlog_result_innerblock > img').map do |elm|
            flag = subpath_from(elm)
            case flag
            when *MaimaiNet::AchievementFlag::RESULT.values; AchievementFlag(result_key: flag)
            when /_dummy$/; nil
            end
          end.compact
          result_position = result_block.at_css('.playlog_result_innerblock img.playlog_matching_icon')&.yield_self do |elm|
            /^\d+/.match(subpath_from(elm))[0].to_i
          end

          challenge_info = nil
          result_block.at_css('div:has(> .playlog_life_block)')&.tap do |elm|
            challenge_type = subpath_from(elm.at_css('img:nth-of-type(1)')).to_sym
            challenge_lives = scan_int(strip(elm.at_css('.playlog_life_block')))

            challenge_info = Model::Result::Challenge.new(
              type: challenge_type,
              lives: Model::Result::Progress.new(**%i(value max).zip(challenge_lives).to_h),
            )
          end

          score_data = {
            score: result_score,
            **%i(deluxe_score combo sync_score).zip([
              result_deluxe_scores, result_combo, result_sync_score,
            ]).reject do |k, li| li.nil? end.map do |k, li|
              [k, Model::Result::Progress.new(**%i(value max).zip(li).to_h)]
            end.to_h,
            grade: result_grade,
            flags: result_flags.map(&:to_sym),
            position: result_position,
          }

          score_cls = score_data.key?(:combo) && score_data.key?(:sync_score) ?
            Model::Result::Score : Model::Result::ScoreLite

          score_info = score_cls.new(**score_data)

          Model::Result::Track.new(
            info: Model::Chart::Info.new(
              web_id: web_id,
              title: song_name,
              type: (chart_type or -'unknown'),
              difficulty: difficulty.id,
              variant: utage_variant,
              level_text: chart_level,
            ),
            score: score_info,
            order: track_order,
            time: play_time,
            challenge: challenge_info,
          )
        end
      end
    end
  end
end
