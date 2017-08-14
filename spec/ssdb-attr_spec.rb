require "spec_helper"

describe SSDBAttr do

  describe "#pool" do
    it "should fetch the named pool if a connection name is passed" do
      options = { :url => "redis://localhost:8888" }

      SSDBAttr.setup(options)

      pool_dbl = double(ConnectionPool)

      expect(SSDBAttr.pools).to receive(:[]).with(:foo).and_return(pool_dbl)
      expect(SSDBAttr.pool(:foo)).to eq(pool_dbl)
    end

    it "should return the default pool if connection name of nil is passed" do
      options = { :url => "redis://localhost:8888" }

      SSDBAttr.setup(options)

      pool_dbl = double(ConnectionPool)

      SSDBAttr.default_pool_name = :default_foo

      expect(SSDBAttr.pools).to receive(:[]).with(:default_foo).and_return(pool_dbl)
      expect(SSDBAttr.pool).to eq(pool_dbl)
    end
  end

  describe "#setup" do
    context "with only one pool" do
      it "should setup a ssdb connection pool with no name specified" do
        options = { :url => "redis://localhost:8888" }

        SSDBAttr.setup(options)

        expect(SSDBAttr.pools.size).to eq(1)
        expect(SSDBAttr.pools[:default]).not_to be_nil
        expect(SSDBAttr.default_pool_name).to eq(:default)
      end

      it "should setup a ssdb connection pool with name specified" do
        options = { :url => "redis://localhost:8888", :name => :main }

        SSDBAttr.setup(options)

        expect(SSDBAttr.pools.size).to eq(1)
        expect(SSDBAttr.default_pool_name).to eq(:main)
        expect(SSDBAttr.pools[:main]).not_to be_nil
        expect(SSDBAttr.default_pool).to eq(SSDBAttr.pools[:main])
      end
    end

    context "with pools" do
      it "should raise error if no name specified" do
        options = [
          { :url => "redis://localhost:8888" },
          { :url => "redis://localhost:6379" }
        ]

        expect { SSDBAttr.setup(options) }.to raise_error(RuntimeError)
      end

      it "should raise error if no default specified" do
        options = [
          { :url => "redis://localhost:8888", :name => :pool1 },
          { :url => "redis://localhost:6379", :name => :pool2 }
        ]

        expect { SSDBAttr.setup(options) }.to raise_error(RuntimeError)
      end

      it "should initialize correctly" do
        options = [
          { :url => "redis://localhost:8888", :name => :ssdb,  :pool_size => 10, :timeout => 2, :default => true },
          { :url => "redis://localhost:6379", :name => :redis, :pool_size => 5,  :timeout => 3 }
        ]

        SSDBAttr.setup(options)

        expect(SSDBAttr.pools.size).to eq(2)
        expect(SSDBAttr.pools[:ssdb]).to be_a(ConnectionPool)
        expect(SSDBAttr.pools[:redis]).to be_a(ConnectionPool)
        expect(SSDBAttr.default_pool_name).to eq(:ssdb)
        expect(SSDBAttr.default_pool).to eq(SSDBAttr.pools[:ssdb])
      end
    end
  end

  describe "#create_pool" do
    it "will use create a connection pool" do
      pool = SSDBAttr.create_pool(:url => "redis://localhost:8888", :pool_size => 10, :timeout => 18)

      expect(pool).not_to be_nil
      expect(pool).to be_a(ConnectionPool)
      expect(pool.instance_variable_get(:@size)).to eq(10)
      expect(pool.instance_variable_get(:@timeout)).to eq(18)

      conn = pool.with { |conn| conn }
      expect(conn).to be_a(Redis)
      expect(conn.client.host).to eq("localhost")
      expect(conn.client.port).to eq(8888)
    end
  end

  describe "#create_conn" do
    context "with url" do
      it do
        conn = SSDBAttr.create_conn(:url => "redis://localhost:8888")

        expect(conn).not_to be_nil
        expect(conn).to be_a(Redis)
        expect(conn.client.host).to eq("localhost")
        expect(conn.client.port).to eq(8888)
      end
    end

    context "with host/port options" do
      it do
        conn = SSDBAttr.create_conn(:host => "localhost", :port => "8888")

        expect(conn).not_to be_nil
        expect(conn).to be_a(Redis)
        expect(conn.client.host).to eq("localhost")
        expect(conn.client.port).to eq(8888)
      end
    end
  end

  describe ".load_attrs" do
    it "returns the values correctly" do
      post1 = Post.create(:name => "lol", :version => 2)
      post2 = Post.create(:name => "dota", :version => 3)

      posts = Post.where(:id => [post1.id, post2.id])

      posts.each do |post|
        expect(post.instance_variable_get(:@name)).to be(nil)
        expect(post.instance_variable_get(:@version)).to be(nil)
      end

      SSDBAttr.load_attrs(posts, :name, :version)

      expect(posts[0].instance_variable_get(:@name)).to eq("lol")
      expect(posts[0].instance_variable_get(:@version)).to eq(2)

      expect(posts[1].instance_variable_get(:@name)).to eq("dota")
      expect(posts[1].instance_variable_get(:@version)).to eq(3)
    end

    it "returns default value correctly if no value in ssdb" do
      post1 = Post.create(:name => "lol")
      post2 = Post.create(:name => "dota")

      posts = Post.where(:id => [post1.id, post2.id])

      posts.each do |post|
        expect(post.instance_variable_get(:@name)).to be(nil)
        expect(post.instance_variable_get(:@version)).to be(nil)
      end

      SSDBAttr.load_attrs(posts, :name, :version)

      expect(posts[0].instance_variable_get(:@name)).to eq("lol")
      expect(posts[0].instance_variable_get(:@version)).to eq(1)

      expect(posts[1].instance_variable_get(:@name)).to eq("dota")
      expect(posts[1].instance_variable_get(:@version)).to eq(1)
    end

    it "doesn't define instance variables for undefined ssdb atts" do
      post1 = Post.create(:name => "lol")
      post2 = Post.create(:name => "dota")

      posts = Post.where(:id => [post1.id, post2.id])

      posts.each do |post|
        expect(post.instance_variable_get(:@name)).to be(nil)
        expect(post.instance_variable_get(:@version)).to be(nil)
      end

      SSDBAttr.load_attrs(posts, :undefined_field)

      posts.each do |post|
        expect(post.instance_variable_defined?(:@undefined_field)).to be(false)
      end
    end
  end
end
