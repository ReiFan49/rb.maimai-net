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
          difficulty = ::Kernel.Difficulty(::Kernel.Pathname(src(header_block.at_css('img.playlog_diff'))).sub_ext('').sub(/.+_/, '').basename)

          dx_container_classes = MaimaiNet::Difficulty::DELUXE.select do |k, v| v.positive? end
            .keys.map do |k| ".playlog_#{k}_container" end
          # info_block = elm.at_css(*dx_container_classes)
          info_block = elm.at_css(".playlog_#{difficulty.key}_container")
          chart_header_block = info_block.at_css('.basic_block')
          result_block = info_block.at_css('.basic_block ~ div:nth-of-type(1)')

          track_order = get_fullint(strip(header_block.at_css('div.sub_title > span:nth-of-type(1)')))
          play_time = Time.strptime(
            strip(header_block.at_css('div.sub_title > span:nth-of-type(2)')) + ' +09:00',
            '%Y/%m/%d %H:%M %z',
          )
          song_name = strip(chart_header_block.children.last)
          chart_level = strip(chart_header_block.at_css('div:nth-of-type(1)'))
          song_jacket = src(result_block.at_css('img.music_img'))
          chart_type = nil
          result_block.at_css('img.playlog_music_kind_icon')&.tap do |elm|
            chart_type = ::Kernel.Pathname(src(elm))&.sub_ext('')&.sub(/.+_/, '')&.basename&.to_s
          end

          result_score = strip(result_block.at_css('.playlog_achievement_txt')).to_f
          result_deluxe_scores = scan_int(strip(result_block.at_css('.playlog_result_innerblock .playlog_score_block div:nth-of-type(1)')))
          result_grade = ::Kernel.Pathname(::Kernel.URI(src(result_block.at_css('.playlog_scorerank'))).path).sub_ext('')&.sub(/.+_/, '')&.basename&.to_s.to_sym
          result_flags = result_block.css('.playlog_result_innerblock > img').map do |elm|
            flag = ::Kernel.Pathname(::Kernel.URI(src(elm)).path).sub_ext('')&.basename.to_s
            case flag
            when *MaimaiNet::AchievementFlag::RESULT.values; MaimaiNet::AchievementFlag.new(result_key: flag)
            when /_dummy$/; nil
            end
          end.compact

          challenge_info = nil
          result_block.at_css('div:has(> .playlog_life_block)')&.tap do |elm|
            challenge_type = ::Kernel.Pathname(::Kernel.URI(src(elm.at_css('img:nth-of-type(1)'))).path).basename.sub_ext('').sub(/.+_/, '').to_s.to_sym
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
