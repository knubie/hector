module Hector
  module Commands
    module List
      def on_list
        respond_with("321", :source => Hector.server_name, :text => "Channel :Users Name")
        Channel.list_all.each do |channel|
          if (channel.secret? && channel.has_session?(self)) || !channel.secret?
            if topic = channel.topic
              respond_with("322", nickname, channel.name, channel.user_sessions.count, :source => Hector.server_name, :text => topic[:body])
            else
              respond_with("322", nickname, channel.name, channel.user_sessions.count, :source => Hector.server_name, :text => "No topic is set.")
            end
          end
        end
        respond_with("323", :source => Hector.server_name, :text => "End of /LIST")
      end

    end
  end
end
