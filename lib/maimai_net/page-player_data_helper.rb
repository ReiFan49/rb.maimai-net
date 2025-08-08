module MaimaiNet
  module Page
    module PlayerDataHelper
      def self.process(elm)
        HelperBlock.send(:new, nil).instance_exec do
          counter_elements = elm.css <<-CSS.strip
            div:not(.musiccount_block):not(.clearfix) ~ .musiccount_block:has(~ .clearfix),
            div:not(.musiccount_block):not(.clearfix) ~ .clearfix:has(~ .clearfix)
          CSS
          cascaded_data = []
          data = []
          column_id = 0
          counter_elements.each do |elm|
            if elm.classes.include?('clearfix') then
              column_id = 0
              next
            end

            cascaded_data << [] if column_id.succ > cascaded_data.size

            cascaded_data[column_id] << Model::SongCount.new(
              **%i(achieved total).zip(scan_int(strip(elm))).to_h
            )
            column_id += 1
          end

          cascaded_data.each do |column_data| data.concat column_data end
          data
        end
      end
    end
  end
end
