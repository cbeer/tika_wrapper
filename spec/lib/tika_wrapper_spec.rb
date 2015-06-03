require 'spec_helper'

describe TikaWrapper do
  describe ".wrap" do
    it "should launch tika" do
      TikaWrapper.wrap do |tika|
        expect do
          Timeout::timeout(15) do
            TCPSocket.new('127.0.0.1', tika.port).close
          end
        end.not_to raise_exception
      end
    end
  end
end
