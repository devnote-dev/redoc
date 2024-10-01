require "./spec_helper"

describe Redoc do
  context "query" do
    it "should parse identifiers as symbols" do
      namespace, symbol, scope = Redoc.parse_query "puts"
      namespace.should be_empty
      symbol.should eq "puts"
      scope.should eq Redoc::QueryScope::All
    end

    it "should parse a constant as a namespace" do
      namespace, symbol, scope = Redoc.parse_query "STDOUT"
      namespace.should eq %w[STDOUT]
      symbol.should be_nil
      scope.should eq Redoc::QueryScope::All
    end

    it "should parse constants as namespaces" do
      namespace, symbol, scope = Redoc.parse_query "IO::Memory"
      namespace.should eq %w[IO Memory]
      symbol.should be_nil
      scope.should eq Redoc::QueryScope::All

      namespace, symbol, scope = Redoc.parse_query "::JSON::Any::Type"
      namespace.should eq %w[JSON Any Type]
      symbol.should be_nil
      scope.should eq Redoc::QueryScope::All
    end

    it "should parse paths with periods" do
      namespace, symbol, scope = Redoc.parse_query "IO.puts"
      namespace.should eq %w[IO]
      symbol.should eq "puts"
      scope.should eq Redoc::QueryScope::Class
    end

    it "should parse paths with hashtags" do
      namespace, symbol, scope = Redoc.parse_query "Array#size"
      namespace.should eq %w[Array]
      symbol.should eq "size"
      scope.should eq Redoc::QueryScope::Instance

      namespace, symbol, scope = Redoc.parse_query "Hash#[]"
      namespace.should eq %w[Hash]
      symbol.should eq "[]"
      scope.should eq Redoc::QueryScope::Instance
    end

    it "disallows invalid identifiers" do
      expect_raises(Redoc::Error) do
        Redoc.parse_query ".puts"
      end

      expect_raises(Redoc::Error) do
        Redoc.parse_query "#puts"
      end

      expect_raises(Redoc::Error) do
        Redoc.parse_query "puts::"
      end

      expect_raises(Redoc::Error) do
        Redoc.parse_query "to_s.nil?"
      end

      expect_raises(Redoc::Error) do
        Redoc.parse_query "IO.Memory"
      end

      expect_raises(Redoc::Error) do
        Redoc.parse_query "JSON#Any"
      end
    end

    it "parses operator tokens" do
      %w[+ - * ** / // % | ! !~ & &+ &- &* ^ ` ~ =~ == === < << <= <=> >> > >= [] []? []=].each do |op|
        Redoc::METHOD_PATTERN.matches?(op).should be_true
      end
    end
  end

  # context "project" do
  #   project = File.open "./sample.json" do |file|
  #     Redoc.load file
  #   end
  # end
end
