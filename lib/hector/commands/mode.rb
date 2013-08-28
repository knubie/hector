module Hector
  module Commands
    module Mode
      def on_mode
        # <nickname> {[+|-]|i|o}
        subject = find(request.args.first)

        if subject.channel?
          if requesting_modes?
            respond_with("324", nickname, subject.name, "+#{subject.modes.join('')}", :source => Hector.server_name)
            respond_with("329", nickname, subject.name, subject.created_at.to_i, :source => Hector.server_name)
          elsif requesting_bans?
            respond_with("368", nickname, subject.name, :text => "End of Channel Ban List", :source => Hector.server_name)
          else
            if channels.include?(subject)
              if subject.ops.include?(self)
                # Set channel modes
                subject.set_mode_flags parse_modes[:channel_add_flags], parse_modes[:channel_remove_flags]
                respond_with("324", nickname, subject.name, "+#{subject.modes.join('')}", :source => Hector.server_name)
                respond_with("329", nickname, subject.name, subject.created_at.to_i, :source => Hector.server_name)
                subject.broadcast(:mode, subject.name, :source => source, :text => request.args[1])
              else
                respond_with("482", subject.name, "You're not a channel operator.", :source => Hector.server_name)
              end
            else
              respond_with("442", request.args.first, "You're not on that channel", :source => Hector.server_name)
            end
          end
        else
          if requesting_modes?
            respond_with("221", nickname, "+", :source => Hector.server_name)
          else
            # Set user modes
          end
        end
      end

      private
        def requesting_modes?
          request.args.length == 1
        end

        def requesting_bans?
          request.args.length == 2 && request.args.last[/^\+?b$/]
        end

        def parse_modes
          # <channel> {[+|-]|o|s|i|k|b} [<user>] [<ban mask>]
          channel_adds = /\+([^\+\-]+)/.match(request.args[1])
          channel_removes = /\-([^\+\-]+)/.match(request.args[1])

          channel_adds ||= ['']
          channel_adds = channel_adds[1] || ''
          channel_adds = channel_adds.split('')

          channel_removes ||= ['']
          channel_removes = channel_removes[1] || ''
          channel_removes = channel_removes.split('')

          channel_adds.select! { |e| e =~ /[osikb]/ }
          channel_removes.select! { |e| e =~ /[osikb]/ }
          {
            :channel_add_flags => channel_adds.select { |e| e =~ /[si]/ },
            :channel_remove_flags => channel_removes.select { |e| e =~ /[sik]/ },
            :channel_add_commands => channel_adds.select { |e| e =~ /[obk]/ },
            :channel_remove_commands => channel_adds.select { |e| e =~ /[ob]/ },
            :command_args => request.args[2..-1]
          }
        end

        def respond_to_modes
          respond_with("324", nickname, subject.name, "+#{subject.modes.join('')}", :source => Hector.server_name)
          respond_with("329", nickname, subject.name, subject.created_at.to_i, :source => Hector.server_name)
        end
    end
  end
end
