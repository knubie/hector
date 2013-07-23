module Hector
  module Commands
    module Kick
      def on_kick
        if session = Session.find(request.args[1])
          channel = Channel.find(request.args.first)
          if channels.include?(channel)
            if channel.ops.include?(self)
              channel.broadcast(:kick, channel.name, session.nickname ,:source => source, :text => request.text)
              channel.part(session)
            else
              respond_with("482", channel.name, "You're not a channel operator.", :source => Hector.server_name)
            end
          else
            respond_with("442", request.args.first, "You're not on that channel", :source => Hector.server_name)
          end
        else
          raise NoSuchNickOrChannel, nickname
        end
      end
    end
  end
end
