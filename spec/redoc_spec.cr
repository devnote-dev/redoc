require "./spec_helper"

describe Redoc do
  context "query" do
    it "should parse identifiers as symbols" do
      namespace, symbol, kind = Redoc.parse_query "puts"
      namespace.should be_empty
      symbol.should eq "puts"
      kind.should eq Redoc::QueryKind::All

      namespace, symbol, kind = Redoc.parse_query "#puts"
      namespace.should be_empty
      symbol.should eq "puts"
      kind.should eq Redoc::QueryKind::Instance

      namespace, symbol, kind = Redoc.parse_query ".puts"
      namespace.should be_empty
      symbol.should eq "puts"
      kind.should eq Redoc::QueryKind::Class
    end

    it "should parse a constant as a namespace" do
      namespace, symbol, kind = Redoc.parse_query "STDOUT"
      namespace.should eq %w[STDOUT]
      symbol.should be_nil
      kind.should eq Redoc::QueryKind::All
    end

    it "should parse constants as namespaces" do
      namespace, symbol, kind = Redoc.parse_query "IO::Memory"
      namespace.should eq %w[IO Memory]
      symbol.should be_nil
      kind.should eq Redoc::QueryKind::All

      namespace, symbol, kind = Redoc.parse_query "::JSON::Any::Type"
      namespace.should eq %w[JSON Any Type]
      symbol.should be_nil
      kind.should eq Redoc::QueryKind::All
    end

    it "should parse paths with periods" do
      namespace, symbol, kind = Redoc.parse_query "IO.puts"
      namespace.should eq %w[IO]
      symbol.should eq "puts"
      kind.should eq Redoc::QueryKind::Class
    end

    it "should parse paths with hashtags" do
      namespace, symbol, kind = Redoc.parse_query "Array#size"
      namespace.should eq %w[Array]
      symbol.should eq "size"
      kind.should eq Redoc::QueryKind::Instance

      namespace, symbol, kind = Redoc.parse_query "Hash#[]"
      namespace.should eq %w[Hash]
      symbol.should eq "[]"
      kind.should eq Redoc::QueryKind::Instance
    end

    it "disallows invalid identifiers" do
      expect_raises(Error) do
        Redoc.parse_query "::puts"
      end

      expect_raises(Error) do
        Redoc.parse_query "puts::"
      end
    end
  end

  # context "project" do
  #   project = File.open "./sample.json" do |file|
  #     Redoc.load file
  #   end
  # end
end
