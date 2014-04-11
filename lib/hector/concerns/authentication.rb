module Hector
  module Concerns
    module Authentication
      def on_user
        @username = request.args.first
        @hostname = "hector.irc"
        @realname = request.text
        authenticate
      end

      def on_pass
        @password = request.text
        authenticate
      end

      def on_nick
        @nickname = request.text
        authenticate
      end
      
      def on_cap
        # Do nothing
      end

      protected
        def authenticate
          start_timeout
          set_identity
          set_session
        end

        def set_identity
          if @username && @password && !@identity
            Identity.authenticate(@username, @password) do |identity|
              if @identity = identity
                cancel_timeout
                set_session
              elsif @password.include?(":")
                @username, @password = @password.split(":")
                set_identity
              else
                error InvalidPassword
              end
            end
          end
        end

        def set_session
          if @identity && @nickname && !@session
            if UserSession.find @nickname
              error NicknameInUse, @nickname
            else
              @session = UserSession.create(@nickname, self, @identity, @realname, @hostname)
            end
          end
        end
        
        def start_timeout
          @timer ||= EventMachine::Timer.new(30) do
            close_connection(true)
          end
        end
        
        def cancel_timeout
          @timer.cancel if @timer
        end
    end
  end
end
