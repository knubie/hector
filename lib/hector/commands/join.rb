module Hector
  module Commands
    module Join
      def on_join
        request.args.first.split(/,(?=[#&+!])/).each do |channel_name|
          channel = Channel.find_or_create(channel_name)
          if !channel.invite_only? || (channel.invite_only? && channel.invites.include?(self))
            if channel.join(self)
              channel.broadcast(:join, :source => source, :text => channel.name)
              respond_to_topic(channel)
              respond_to_names(channel)
            end
          else
            respond_with("473", channel.name, "You must be invited to join this channel.", :source => Hector.server_name)
          end
        end
      end
    end
  end
end
