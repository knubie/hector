module Hector
  class Channel
    attr_reader :name, :topic, :user_sessions, :ops, :created_at, :modes, :invites, :op_users, :ban_list

    class << self
      def find(name)
        channels[normalize(name)]
      end

      def list_all
        #channels.keys
        channels.values
      end

      def find_all_for_session(session)
        channels.values.find_all do |channel|
          channel.has_session?(session)
        end
      end

      def create(name)
        new(name).tap do |channel|
          channels[normalize(name)] = channel
        end
      end

      def find_or_create(name)
        find(name) || create(name)
      end

      def delete(name)
        channels.delete(name)
      end

      def normalize(name)
        name.force_encoding("UTF-8") if name.respond_to?(:force_encoding)
        if name =~ /^[#&+!][#&+!\-\w\p{L}\p{M}\p{N}\p{S}\p{P}\p{Co}]{1,49}$/u && name !~ /,/
          name.downcase
        else
          raise NoSuchChannel, name
        end
      end

      def reset!
        @channels = nil
      end

      protected
        def channels
          @channels ||= {}
        end
    end

    def initialize(name)
      @name = name
      @user_sessions = []
      @ops = []
      @op_users = []
      @ban_list = []
      @modes = []
      @invites = []
      @created_at = Time.now
    end

    def broadcast(command, *args)
      catch :stop do
        Session.broadcast_to(sessions, command, *args)
      end
    end

    def set_mode_flags(add, remove)
      @modes = @modes + add
      @modes = @modes - remove
      @modes.uniq!
    end

    def set_op(session)
      unless @ops.include?(session)
        ops.push(session)
      end
      unless @op_users.include?(session.identity.username)
        op_users.push(session.identity.username)
      end
    end

    def ban(username)
      unless @ban_list.include?(username)
        ban_list.push(username)
      end
    end

    def set_key(key)
    end

    def change_topic(session, topic)
      @topic = { :body => topic, :nickname => session.nickname, :time => Time.now }
    end

    def channel?
      true
    end

    def secret?
      @modes.include?('s')
    end

    def invite_only?
      @modes.include?('i')
    end

    def moderated?
      @modes.include?('m')
    end

    def deliver(message_type, session, options)
      if has_session?(session)
        if !moderated? || (moderated? && ops.include?(session))
          broadcast(message_type, name, options.merge(:except => session))
        else
          raise CannotSendToChannel, name
        end
      else
        raise CannotSendToChannel, name
      end
    end

    def destroy
      self.class.delete(name)
    end

    def has_session?(session)
      sessions.include?(session)
    end

    def join(session)
      return if has_session?(session) || ban_list.include?(session.username)
      if user_sessions.empty? || op_users.include?(session.username)
        set_op(session)
      end
      # If the channel is private and the user leaves, we want them to be able
      # to rejoin, so we'll add them to the invites array. Might want to
      # refactor this in the future to be more explicit.
      @invites.push(session)
      user_sessions.push(session)
    end

    def invite(session)
      return if invites.include?(session)
      @invites.push(session)
    end

    def nicknames
      user_sessions.map do |session|
        #session.nickname
        if ops.include?(session)
          "@#{session.nickname}"
        else
          session.nickname
        end
      end
    end

    def users
      user_sessions.map do |session|
        #session.nickname
        session.username
      end
    end

    def part(session)
      user_sessions.delete(session)
      destroy if user_sessions.empty?
    end

    def services
      Service.all
    end

    def sessions
      services + user_sessions
    end
  end
end
