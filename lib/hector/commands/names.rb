module Hector
  module Commands
    module Names
      def on_names
        channel = Channel.find(request.args.first)
        respond_to_names(channel)
      end

      def respond_to_names(channel)
        if (channel.secret? && channel.has_session?(self)) || !channel.secret?
          responses = Response.apportion_text(channel.nicknames, "353", nickname, "=", channel.name, :source => Hector.server_name)
          responses.each { |response| respond_with(response) }
        end
          respond_with("366", nickname, channel.name, :source => Hector.server_name, :text => "End of /NAMES list.")
      end

      private
        def in_channel?(channel)
          channel.user_sessions.include?(self)
        end

    end
  end
end
