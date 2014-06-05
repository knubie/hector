module Hector
  module Commands
    module Setname
      def on_setname
        setname(request.args.first)
      end
    end
  end
end

