module Hector
  module Commands
    module Invite
      def on_invite
        touch_presence
        nickname = request.args.first
        if session = Session.find(nickname)
          channel = Channel.find(request.args[1])
          if channels.include?(channel) # Inviter is on the channel.
            if !session.channels.include?(channel) # Invitee is not in the channel.
              if !channel.invite_only? || (channel.invite_only? && channel.ops.include?(self))
                session.deliver(:invite, self, :source => source, :text => request.text)
                channel.invite(session)
                respond_with("341", nickname, channel.name, :source => Hector.server_name)
              else
                respond_with("482", channel.name, "You must be a channel operator to invite users.", :source => Hector.server_name)
              end
            else # Invitee is already on channel.
              respond_with("443", nickname, channel.name, "is already on channel", :source => Hector.server_name)
            end
          else # Inviter is not on the channel.
            respond_with("442", request.args[1], "You're not on that channel", :source => Hector.server_name)
          end
        else
          raise NoSuchNickOrChannel, nickname
        end        
      end
    end
  end
end
