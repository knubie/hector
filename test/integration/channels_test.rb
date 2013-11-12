# encoding: UTF-8

require "test_helper"

module Hector
  class ChannelsTest < IntegrationTest
    test :"channels can be joined" do
      authenticated_connections do |c1, c2|
        c1.receive_line "JOIN #test"
        assert_sent_to c1, ":user1!sam@hector.irc JOIN :#test"
        
        c2.receive_line "JOIN #test"
        assert_sent_to c1, ":user2!sam@hector.irc JOIN :#test"
      end
    end
    
    test :"channel names can only start with accepted characters" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#test"
        c.receive_line "JOIN &test"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :&test"
        c.receive_line "JOIN +test"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :+test"
        c.receive_line "JOIN !test"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :!test"
        c.receive_line "JOIN @test"
        assert_not_sent_to c, ":sam!sam@hector.irc JOIN :@test"
        assert_no_such_channel c, "@test"
      end
    end
    
    test :"channel names can contain prefix characters" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN ##"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :##"
        c.receive_line "JOIN #test#"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#test#"
        c.receive_line "JOIN #&"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#&"
        c.receive_line "JOIN ++&#"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :++&#"
        c.receive_line "JOIN !te&t"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :!te&t"
        c.receive_line "JOIN #8*(&x"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#8*(&x"
      end
    end

    test :"joining a channel twice does nothing" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test"
        assert_nothing_sent_to(c) do
          c.receive_line "JOIN #test"
        end
      end
    end

    test :"joining an invalid channel name responds with a 403" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #te,st"
        assert_no_such_channel c, "#te,st"
      end
    end

    test :"joining a channel should send session nicknames" do
      authenticated_connections(:join => "#test") do |c1, c2, c3|
        assert_sent_to c1, ":hector.irc 353 user1 = #test :@user1"
        assert_sent_to c2, ":hector.irc 353 user2 = #test :@user1 user2"
        assert_sent_to c3, ":hector.irc 353 user3 = #test :@user1 user2 user3"
      end
    end

    test :"joining an empty channel gives the joiner operator status" do
      authenticated_connections(:join => "#test") do |c1|
        assert_sent_to c1, ":hector.irc 353 user1 = #test :@user1"
      end
    end

    test :"channel operators can set channel mode flags" do
      authenticated_connections(:join => "#test") do |c1|
        c1.receive_line "MODE #test +s"
        assert_sent_to c1, ":hector.irc 324 user1 #test +s"
      end
    end

    test :"only channel operators can set channel modes" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c2.receive_line "MODE #test +s"
        assert_sent_to c2, ":hector.irc 482 #test You're not a channel operator."
      end
    end

    test :"channel operators can op other channel members" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.receive_line "MODE #test +o user2"
        c2.receive_line "NAMES #test"
        assert_sent_to c2, ":hector.irc 353 user2 = #test :@user1 @user2"
      end
    end

    test :"executing a mode command without sufficient parameters should return 461" do
      authenticated_connections(:join => "#test") do |c1|
        c1.receive_line "MODE #test +o"
        assert_sent_to c1, ":hector.irc 461 #test Not enough parameters."
      end
    end

    test :"secret channels don't show up in WHOIS channel lists" do
      authenticated_connections do |c1, c2|
        c1.receive_line "JOIN #test"
        c1.receive_line "MODE #test +s"
        c1.receive_line "JOIN #test2"
        c2.receive_line "WHOIS user1"
        assert_sent_to c2, ":hector.irc 319 user2 user1 :#test2"
      end
    end

    test :"users in secret channels don't show up in NAMES unless called by a user in that channel" do
      authenticated_connections do |c1, c2|
        c1.receive_line "JOIN #test"
        c1.receive_line "MODE #test +s"
        #c1.receive_line "JOIN #test2"
        c1.receive_line "NAMES #test"
        c2.receive_line "NAMES #test"
        #c2.receive_line "NAMES #test2"

        assert_sent_to c1, ":hector.irc 353 user1 = #test :@user1"
        assert_sent_to c1, ":hector.irc 366 user1 #test :"

        assert_not_sent_to c2, ":hector.irc 353 user2 = #test :@user1"
        assert_sent_to c2, ":hector.irc 366 user2 #test :"
      end
    end

    test :"secret channels don't show up in LIST unless called by a user in that channel" do
      authenticated_connections do |c1, c2|
        c1.receive_line "JOIN #test"
        c1.receive_line "MODE #test +s"
        c1.receive_line "JOIN #test2"
        c2.receive_line "LIST"
        c1.receive_line "LIST"
        assert_sent_to c2, ":hector.irc 321 :Channel :Users Name"
        assert_sent_to c2, ":hector.irc 322 user2 #test2 1 :No topic is set."
        assert_not_sent_to c2, ":hector.irc 322 user2 #test 1 :No topic is set."
        assert_sent_to c2, ":hector.irc 323 :End of /LIST"
        assert_sent_to c1, ":hector.irc 321 :Channel :Users Name"
        assert_sent_to c1, ":hector.irc 322 user1 #test 1 :No topic is set."
        assert_sent_to c1, ":hector.irc 322 user1 #test2 1 :No topic is set."
        assert_sent_to c1, ":hector.irc 323 :End of /LIST"
      end
    end

    test :"only ops can invite users to +i channels" do
      authenticated_connections do |c1, c2, c3|
        c1.receive_line "JOIN #test"
        c2.receive_line "JOIN #test"
        c1.receive_line "MODE #test +i"

        c1.receive_line "INVITE user3 #test :Join us"
        assert_sent_to c1, ":hector.irc 341 user3 #test"
        
        c2.receive_line "INVITE user3 #test :Join us"
        assert_sent_to c2, ":hector.irc 482 #test You must be a channel operator to invite users."
      end
    end

    test :"users cannot join +i channels unless they're invited" do
      authenticated_connections do |c1, c2, c3|
        c1.receive_line "JOIN #test"
        c1.receive_line "MODE #test +i"
        c1.receive_line "INVITE user3 #test :Join us"

        c2.receive_line "JOIN #test"
        assert_sent_to c2, ":hector.irc 473 #test You must be invited to join this channel."

        c3.receive_line "JOIN #test"
        assert_sent_to c3, ":user3!sam@hector.irc JOIN :#test"
      end
    end

    test :"users cannot join channels they've been banned from" do
      authenticated_connections do |c1, c2|
        c1.receive_line "JOIN #test"
        c1.receive_line "MODE #test +b sam"
        c2.receive_line "JOIN #test"
        assert_sent_to c2, ":hector.irc 474 #test You've been banned from this channel."
      end
    end

    test :"only ops can send messages to moderated channels" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.receive_line "JOIN #test"
        c1.receive_line "MODE #test +m"
        c2.receive_line "PRIVMSG #test :hello"
        assert_cannot_send_to_channel c2, "#test"
        c1.receive_line "PRIVMSG #test :hello"
        assert_sent_to c2, ":user1!sam@hector.irc PRIVMSG #test :hello"
      end
    end

    test :"users can be kicked from channels" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.receive_line "KICK #test user2 :Get out"
        assert_sent_to c1, ":user1!sam@hector.irc KICK #test user2 :Get out"
      end
    end

    test :"only channel operators can kick" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c2.receive_line "KICK #test user1 :Get out"
        assert_sent_to c2, ":hector.irc 482 #test You're not a channel operator."
      end
    end

    test :"channels can be parted" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.receive_line "PART #test :lämnar"
        assert_sent_to c1, ":user1!sam@hector.irc PART #test :lämnar"
        assert_sent_to c2, ":user1!sam@hector.irc PART #test :lämnar"
      end
    end

    test :"parting a channel should remove the session from the channel" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.receive_line "PART #test"
        sent_data = capture_sent_data(c2) { c2.receive_line "NAMES #test" }
        assert sent_data !~ /user1/
      end
    end

    test :"quitting should notify all the session's peers" do
      authenticated_connections(:join => "#test") do |c1, c2, c3|
        c1.receive_line "QUIT :outta here"
        assert_not_sent_to c1, ":user1!sam@hector.irc QUIT :Quit: outta here"
        assert_sent_to c2, ":user1!sam@hector.irc QUIT :Quit: outta here"
        assert_sent_to c3, ":user1!sam@hector.irc QUIT :Quit: outta here"
      end
    end

    test :"quitting should notify peers only once" do
      authenticated_connections(:join => ["#test1", "#test2"]) do |c1, c2|
        sent_data = capture_sent_data(c2) { c1.receive_line "QUIT :outta here" }
        assert_equal ":user1!sam@hector.irc QUIT :Quit: outta here\r\n", sent_data
      end
    end

    test :"quitting should remove the session from its channels" do
      authenticated_connections(:join => ["#test1", "#test2"]) do |c1, c2|
        c1.receive_line "QUIT :bye"
        sent_data = capture_sent_data(c2) do
          c2.receive_line "NAMES #test1"
          c2.receive_line "NAMES #test2"
        end
        assert sent_data !~ /user1/
      end
    end

    test :"disconnecting without quitting should notify peers" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.close_connection
        assert_sent_to c2, ":user1!sam@hector.irc QUIT :Connection closed"
      end
    end

    test :"disconnecting should remove the session from its channels" do
      authenticated_connections(:join => ["#test1", "#test2"]) do |c1, c2|
        c1.close_connection
        sent_data = capture_sent_data(c2) do
          c2.receive_line "NAMES #test1"
          c2.receive_line "NAMES #test2"
        end
        assert sent_data !~ /user1/
      end
    end

    test :"names command should send session nicknames" do
      authenticated_connections(:join => "#test") do |c1, c2, c3|
        c1.receive_line "NAMES #test"
        assert_sent_to c1, ":hector.irc 353 user1 = #test :@user1 user2 user3"
        assert_sent_to c1, ":hector.irc 366 user1 #test :"
      end
    end

    test :"names command should be split into 512-byte responses" do
      authenticated_connections(:join => "#test") do |c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31, c32, c33, c34, c35, c36, c37, c38, c39, c40, c41, c42, c43, c44, c45, c46, c47, c48, c49, c50, c51, c52, c53, c54, c55, c56, c57, c58, c59, c60, c61, c62, c63, c64, c65, c66, c67, c68, c69, c70|
        c1.receive_line "NAMES #test"
        assert_sent_to c1, ":hector.irc 353 user1 = #test :@user1 user2 user3 user4 user5 user6 user7 user8 user9 user10 user11 user12 user13 user14 user15 user16 user17 user18 user19 user20 user21 user22 user23 user24 user25 user26 user27 user28 user29 user30 user31 user32 user33 user34 user35 user36 user37 user38 user39 user40 user41 user42 user43 user44 user45 user46 user47 user48 user49 user50 user51 user52 user53 user54 user55 user56 user57 user58 user59 user60 user61 user62 user63 user64 user65 user66 user67 user68 user69"
        assert_sent_to c1, ":hector.irc 353 user1 = #test :user70"
        assert_sent_to c1, ":hector.irc 366 user1 #test :"
      end
    end

    test :"list command should send all channels" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test1"
        c.receive_line "JOIN #test2"
        c.receive_line "TOPIC #test2 :hello world"
        c.receive_line "LIST"
        assert_sent_to c, ":hector.irc 321 :Channel :Users Name"
        assert_sent_to c, ":hector.irc 322 sam #test1 1 :No topic is set."
        assert_sent_to c, ":hector.irc 322 sam #test2 1 :hello world"
        assert_sent_to c, ":hector.irc 323 :End of /LIST"
      end
    end

    test :"topic command with text should set the channel topic" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.receive_line "TOPIC #test :this is my topic"
        assert_sent_to c1, ":user1!sam@hector.irc TOPIC #test :this is my topic"
        assert_sent_to c2, ":user1!sam@hector.irc TOPIC #test :this is my topic"
      end
    end

    test :"topic command with no arguments should send the channel topic" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test"
        c.receive_line "TOPIC #test :hello world"
        assert_sent_to c, ":hector.irc 332 sam #test :hello world" do
          c.receive_line "TOPIC #test"
        end
      end
    end

    test :"topic command sends timestamp and nickname" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test"
        c.receive_line "TOPIC #test :hello world"
        assert_sent_to c, /^:hector\.irc 333 sam #test sam \d+/ do
          c.receive_line "TOPIC #test"
        end
      end
    end

    test :"topic command with no arguments should send 331 when no topic is set" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test"
        assert_sent_to c, ":hector.irc 331 sam #test :" do
          c.receive_line "TOPIC #test"
        end
      end
    end

    test :"channel topics are erased when the last session parts" do
      authenticated_connection("sam").tap do |c|
        c.receive_line "JOIN #test"
        c.receive_line "TOPIC #test :hello world"
        c.receive_line "PART #test"
      end

      authenticated_connection("clint").tap do |c|
        c.receive_line "JOIN #test"
        assert_not_sent_to c, ":hector.irc 332 clint #test :hello world"
      end
    end

    test :"channel topics are erased when the last session quits" do
      authenticated_connection("sam").tap do |c|
        c.receive_line "JOIN #test"
        c.receive_line "TOPIC #test :hello world"
        c.receive_line "QUIT"
      end

      authenticated_connection("clint").tap do |c|
        c.receive_line "JOIN #test"
        assert_not_sent_to c, ":hector.irc 332 clint #test :hello world"
      end
    end

    test :"sending a WHO command to an empty or undefined channel should produce an end of list message" do
      authenticated_connection.tap do |c|
        c.receive_line "WHO #test"
        assert_sent_to c, ":hector.irc 315 sam #test"
        assert_not_sent_to c, ":hector.irc 352"
      end
    end

    test :"sending a WHO command to a channel you have joined should list each occupant's info" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c2.receive_line "WHO #test"
        assert_sent_to c2, ":hector.irc 352 user2 #test sam hector.irc hector.irc user1 H :0 Sam Stephenson"
        assert_sent_to c2, ":hector.irc 352 user2 #test sam hector.irc hector.irc user2 H :0 Sam Stephenson"
        assert_sent_to c2, ":hector.irc 315 user2 #test"
      end
    end

    test :"sending a WHO command to an active channel you've not yet joined should still list everyone" do
      authenticated_connections do |c1, c2, c3|
        c1.receive_line "JOIN #test"
        c2.receive_line "JOIN #test"
        c3.receive_line "WHO #test"
        assert_sent_to c3, ":hector.irc 352 user3 #test sam hector.irc hector.irc user1 H :0 Sam Stephenson"
        assert_sent_to c3, ":hector.irc 352 user3 #test sam hector.irc hector.irc user2 H :0 Sam Stephenson"
        assert_sent_to c3, ":hector.irc 315 user3 #test"
      end
    end

    test :"sending a WHO command about a real user should list their user data" do
      authenticated_connections do |c1, c2|
        c1.receive_line "WHO user2"
        assert_sent_to c1, ":hector.irc 352 user1 user2 sam hector.irc hector.irc user2 H :0 Sam Stephenson"
        assert_sent_to c1, ":hector.irc 315 user1 user2"
      end
    end

    test :"sending a WHO command about a non-existent user should produce an end of list message" do
      authenticated_connection.tap do |c|
        c.receive_line "WHO user2"
        assert_sent_to c, ":hector.irc 315 sam user2"
        assert_not_sent_to c, ":hector.irc 352"
      end
    end

    test :"sending a WHOIS on a non-existent user should reply with a 401 then 318" do
      authenticated_connection.tap do |c|
        c.receive_line "WHOIS user2"
        assert_sent_to c, ":hector.irc 401"
        assert_sent_to c, ":hector.irc 318"
      end
    end

    test :"sending a WHOIS on a user not on any channels should list the following items and 318" do
      authenticated_connections do |c1, c2|
        c1.receive_line "WHOIS user2"
        assert_sent_to c1, ":hector.irc 311"
        assert_sent_to c1, ":hector.irc 312"
        assert_sent_to c1, ":hector.irc 317"
        assert_sent_to c1, ":hector.irc 318"
        assert_not_sent_to c1, ":hector.irc 319" # no channels
      end
    end

    test :"sending a WHOIS on a user on channels should list the following items and 318" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c1.receive_line "WHOIS user2"
        assert_sent_to c1, ":hector.irc 311"
        assert_sent_to c1, ":hector.irc 312"
        assert_sent_to c1, ":hector.irc 319"
        assert_sent_to c1, ":hector.irc 317"
        assert_sent_to c1, ":hector.irc 318"
      end
    end

    test :"sending a WHOIS to a user with an away message should send a 301" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c2.receive_line "AWAY :wut heh"
        c1.receive_line "WHOIS user2"
        assert_sent_to c1, ":hector.irc 301"
      end
    end

    test :"whois includes the correct channels" do
      authenticated_connections(:join => "#test") do |c1, c2|
        c2.receive_line "JOIN #tset"
        c2.receive_line "WHOIS user1"
        assert_not_sent_to c2, /^:hector\.irc 319.*#tset.*/
      end
    end

    test :"requesting the modes for a channel should reply with 324 and 329" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test"
        c.receive_line "MODE #test"
        assert_sent_to c, ":hector.irc 324"
        assert_sent_to c, /^:hector\.irc 329 sam #test \d+/
        assert_not_sent_to c, ":hector.irc 368"
      end
    end

    test :"requesting the ban list for a channel should reply with 368" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #test"
        c.receive_line "MODE #test b"
        assert_not_sent_to c, ":hector.irc 324"
        assert_not_sent_to c, ":hector.irc 329"
        assert_sent_to c, ":hector.irc 368"
      end
    end

    test :"requesting modes for a non-existent channel should return 401" do
      authenticated_connection.tap do |c|
        c.receive_line "MODE #test"
        assert_no_such_nick_or_channel c, "#test"
        assert_not_sent_to c, ":hector.irc 324"
        assert_not_sent_to c, ":hector.irc 329"
        assert_not_sent_to c, ":hector.irc 368"
      end
    end

    test :"requesting modes for a non-existent user should return 401" do
      authenticated_connection.tap do |c|
        c.receive_line "MODE bob"
        assert_no_such_nick_or_channel c, "bob"
        assert_not_sent_to c, ":hector.irc 221"
      end
    end

    test :"changing nicknames should notify peers" do
      authenticated_connections(:join => "#test") do |c1, c2, c3, c4|
        c4.receive_line "PART #test"
        c1.receive_line "NICK sam"

        assert_sent_to c1, ":user1 NICK sam"
        assert_sent_to c2, ":user1 NICK sam"
        assert_sent_to c3, ":user1 NICK sam"
        assert_not_sent_to c4, ":user1 NICK sam"
      end
    end

    test :"changing realname should notify peers" do
      authenticated_connections(:join => "#test") do |c1, c2, c3, c4|
        c4.receive_line "PART #test"
        c1.receive_line "REALNAME :Sam Stephenson"

        assert_sent_to c1, /^:hector\.irc 352 user1 .* user1 H :0 Sam Stephenson/
        assert_sent_to c2, /^:hector\.irc 352 user2 .* user1 H :0 Sam Stephenson/
        assert_sent_to c3, /^:hector\.irc 352 user3 .* user1 H :0 Sam Stephenson/
        assert_not_sent_to c4, ":hector.irc 352 user4"
      end
    end

    test :"multiple channels can be joined with a single command" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #channel1,#channel2,#channel3"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#channel1"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#channel2"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#channel3"
      end
    end

    test :"unicode channels can be joined" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #リンゴ"
        c.receive_line "JOIN #tuffieħa"
        c.receive_line "JOIN #تفاحة"
        c.receive_line "JOIN #תפוח"
        c.receive_line "JOIN #яблоко"
        c.receive_line "JOIN #"
        c.receive_line "JOIN #☬☃☢☠☆☆☆"
        c.receive_line "JOIN #ǝʃddɐ"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#リンゴ"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#tuffieħa"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#تفاحة"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#תפוח"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#яблоко"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#☬☃☢☠☆☆☆"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#ǝʃddɐ"
      end
    end
    
    test :"channel names are coerced to UTF-8" do
      authenticated_connection.tap do |c|
        c.receive_line "JOIN #chännel".force_encoding("ASCII-8BIT")
        c.receive_line "JOIN #channèl".force_encoding("ASCII-8BIT")
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#chännel"
        assert_sent_to c, ":sam!sam@hector.irc JOIN :#channèl"
      end
    end if String.method_defined?(:force_encoding)

    test :"names command with unicode nicks should still be split into 512-byte responses" do
      authenticated_connections(:join => "#test", :nickname => "⌘lee") do |c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31, c32, c33, c34, c35, c36, c37, c38, c39, c40, c41, c42, c43, c44, c45, c46, c47, c48, c49, c50, c51, c52, c53, c54, c55, c56, c57, c58, c59, c60, c61, c62, c63, c64, c65, c66, c67, c68, c69, c70|
        c1.receive_line "NAMES #test"

        first_line = ":hector.irc 353 ⌘lee1 = #test :@⌘lee1 ⌘lee2 ⌘lee3 ⌘lee4 ⌘lee5 ⌘lee6 ⌘lee7 ⌘lee8 ⌘lee9 ⌘lee10 ⌘lee11 ⌘lee12 ⌘lee13 ⌘lee14 ⌘lee15 ⌘lee16 ⌘lee17 ⌘lee18 ⌘lee19 ⌘lee20 ⌘lee21 ⌘lee22 ⌘lee23 ⌘lee24 ⌘lee25 ⌘lee26 ⌘lee27 ⌘lee28 ⌘lee29 ⌘lee30 ⌘lee31 ⌘lee32 ⌘lee33 ⌘lee34 ⌘lee35 ⌘lee36 ⌘lee37 ⌘lee38 ⌘lee39 ⌘lee40 ⌘lee41 ⌘lee42 ⌘lee43 ⌘lee44 ⌘lee45 ⌘lee46 ⌘lee47 ⌘lee48 ⌘lee49 ⌘lee50 ⌘lee51 ⌘lee52 ⌘lee53\r\n"
        second_line = ":hector.irc 353 ⌘lee1 = #test :⌘lee54 ⌘lee55 ⌘lee56 ⌘lee57 ⌘lee58 ⌘lee59 ⌘lee60 ⌘lee61 ⌘lee62 ⌘lee63 ⌘lee64 ⌘lee65 ⌘lee66 ⌘lee67 ⌘lee68 ⌘lee69 ⌘lee70\r\n"

        assert_sent_to c1, first_line
        assert_sent_to c1, second_line
        assert_sent_to c1, ":hector.irc 366 ⌘lee1 #test :"

        assert (first_line.size < 512)
        assert (second_line.size  < 512)
      end
    end

  end
end
