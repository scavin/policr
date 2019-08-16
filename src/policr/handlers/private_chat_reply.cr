module Policr
  handler PrivateChatReply do
    allow_edit

    @chat_info : {Int64, Int32}?

    match do
      all_pass? [
        from_private_chat?(msg),
        (reply_msg = msg.reply_to_message),
        (@chat_info = Cache.private_chat_msg?("", reply_msg.message_id)), # 针对无关私聊的回复？
        msg.text,
      ]
    end

    handle do
      if (text = msg.text) && (chat_info = @chat_info)
        user_id, reply_to_msg_id = chat_info

        unless maked_operation?(text, user_id)
          bot.send_message(
            user_id,
            text: text,
            reply_to_message_id: reply_to_msg_id
          )
        end
      end
    end

    def maked_operation?(text, user_id)
      if text.starts_with?("!")
        begin
          args = text[1..].split(" ")
          case args[0]
          when "rr" # Remove report
            if (appeal = Model::Appeal.find(args[1].to_i)) &&
               (report = appeal.report)
              if appeal.author_id == user_id
                Model::Report.delete(report.id)
                Model::Appeal.delete(appeal.id)
                bot.send_message user_id, t("appeal.human.removed_report", {appeal_id: appeal.id})
                spawn bot.delete_message "@#{bot.snapshot_channel}", report.target_snapshot_id
                spawn bot.delete_message "@#{bot.voting_channel}", report.post_id
              else
                bot.send_message bot.owner_id, t("appeal.human.illegal_id")
              end
            end
          else
            nil
          end
        rescue ex : Exception
          bot.send_message bot.owner_id, ex.message || ex.to_s
        end
      end
    end
  end
end
