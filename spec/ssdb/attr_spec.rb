require "spec_helper"

describe SSDB::Attr do
  context "Post" do
    let(:post) { Post.create(updated_at: 1.day.ago, saved_at: 1.day.ago, changed_at: 1.day.ago) }
    let(:redis) { Redis.new(:url => 'redis://localhost:8888') }

    describe "@ssdb_attr_definition" do
      it "should set `@ssdb_attr_definition` correctly"  do
        ssdb_attr_definition = Post.instance_variable_get(:@ssdb_attr_definition)

        expect(ssdb_attr_definition[:name][:type]).to eq(:string)
        expect(ssdb_attr_definition[:int_version][:type]).to eq(:integer)
        expect(ssdb_attr_definition[:default_title][:type]).to eq(:string)
        expect(ssdb_attr_definition[:title][:type]).to eq(:string)
        expect(ssdb_attr_definition[:content][:type]).to eq(:string)
        expect(ssdb_attr_definition[:version][:type]).to eq(:integer)
        expect(ssdb_attr_definition[:default_version][:type]).to eq(:integer)
        expect(ssdb_attr_definition[:field_with_validation][:type]).to eq(:string)

        expect(ssdb_attr_definition[:default_title][:default]).to eq("Untitled")
        expect(ssdb_attr_definition[:default_version][:default]).to eq(100)
      end
    end

    it "should respond to methods" do
      expect(post.respond_to?(:name)).to be true
      expect(post.respond_to?(:name=)).to be true
      expect(post.respond_to?(:name_default_value)).to be true
      expect(post.respond_to?(:name_was)).to be true
      expect(post.respond_to?(:name_change)).to be true
      expect(post.respond_to?(:name_changed?)).to be true
      expect(post.respond_to?(:restore_name!)).to be true
      expect(post.respond_to?(:name_will_change!)).to be true
    end

    describe "#ssdb_attr_type" do
      it "returns the type for a defined attribute" do
        expect(post.ssdb_attr_type("name")).to eq(:string)
        expect(post.ssdb_attr_type("int_version")).to eq(:integer)
      end
    end

    describe "#attribute=" do
      it "shouldn't change the attribute value in SSDB" do
        post.title = "foobar"
        expect(redis.get(post.send(:ssdb_attr_key, :title))).not_to eq("foobar")
      end

      it "should change the attribute value" do
        post.title = "foobar"
        expect(post.title).to eq("foobar")
      end

      it "should track attirbute changes if value changed" do
        expect(post).to receive(:title_will_change!)
        post.title = "foobar"
      end
    end

    describe "#attirbute_default_value" do
      it "returns correct default value" do
        post.default_title = "changed"
        post.default_version = 99

        expect(post.default_title_default_value).to eq("Untitled")
        expect(post.default_version_default_value).to eq(100)
      end

      it "returns nil if the attribute without :default option" do
        expect(post.title_default_value).to be_nil
      end
    end

    describe "#reload_ssdb_attrs" do
      it "should reload attribute values from SSDB" do
        post = Post.create(title: "foobar", version: 4)
        post.title = "fizzbuzz"
        post.version = 3

        post.send(:reload_ssdb_attrs)
        expect(post.instance_variable_get(:@title)).to eq("foobar")
        expect(post.instance_variable_get(:@version)).to eq(4)
        expect(post.instance_variable_get(:@content)).to be_nil
      end
    end

    describe "#save_ssdb_attrs" do
      it "saves attribute values in ssdb when create a new record" do
        post = Post.create(title: "foobar")

        expect(redis.get("posts:#{post.id}:title")).to eq("foobar")
      end

      it "saves attribute values in ssdb when update a record" do
        expect(redis.get("posts:#{post.id}:title")).to be_nil

        post.update(title: "foobar")

        expect(redis.get("posts:#{post.id}:title")).to eq("foobar")
      end

      it "removes the attribute from ssdb when update the attribute to nil" do
        post.update(title: "foobar")
        expect(redis.get("posts:#{post.id}:title")).to eq("foobar")

        post.update(title: nil)
        expect(redis.get("posts:#{post.id}:title")).to be_nil
      end
    end

    describe "#clear_ssdb_attrs" do
      before do
        post.update(:title => "foobar2")
      end

      it "should remove attribute from ssdb" do
        post.send(:clear_ssdb_attrs)
        expect(redis.exists("posts:#{post.id}:title")).to be false
      end
    end

    describe "#load_ssdb_attrs" do
      it "loads the values of all specified attrs" do
        post = Post.create(title: "foobar", version: 4)
        post = Post.find(post.id)

        expect(post.instance_variable_get(:@title)).to be_nil
        expect(post.instance_variable_get(:@version)).to be_nil
        expect(post.instance_variable_get(:@content)).to be_nil

        post.load_ssdb_attrs(:title, :version, :content, :noexistent)
        expect(post.instance_variable_get(:@title)).to eq("foobar")
        expect(post.instance_variable_get(:@version)).to eq(4)
        expect(post.instance_variable_get(:@content)).to be_nil
        expect(post.instance_variable_defined?(:@noexistent)).to eq(false)
      end
    end

    describe "#ssdb_attr_key" do
      it "should return correct key" do
        expect(post.send(:ssdb_attr_key, "name")).to eq("posts:#{post.id}:name")
      end
    end

    context "type: :integer" do
      it "default value should be nil" do
        expect(post.int_version).to be_nil
      end

      it "should hold integer value and return it" do
        post.int_version = 4
        expect(post.int_version).to eq(4)
      end

      it "default value with `:default` option" do
        expect(post.default_version).to eq(100)
      end
    end

    context "type: :string" do
      it "default value should be nil" do
        expect(post.title).to be_nil
      end

      it "default value with `:default` option" do
        expect(post.default_title).to eq("Untitled")
      end
    end

    context "callbacks" do
      it "should save attribute values in SSDB when AR object save" do
        post = Post.new
        expect(post).to receive(:save_ssdb_attrs)
        post.save
      end

      it "should clear attribute values in SSDB when AR object destroyed" do
        expect(post).to receive(:clear_ssdb_attrs)
        post.destroy
      end
    end

    context "validation" do
      it "should call the validation method" do
        post.field_with_validation = "hellow world"
        expect(post).to receive(:validate_field)
        post.save
      end

      context "on validation passed" do
        it do
          post.field_with_validation = "hello world"

          expect(post.save).to eq(true)
          expect(redis.get("posts:#{post.id}:field_with_validation")).to eq("hello world")
          expect(post.errors.empty?).to be_truthy
        end
      end

      context "on validation failed" do
        it "should not update the value in SSDB if validation fails" do
          post.field_with_validation = "foobar"

          expect(post.save).to eq(false)
          expect(redis.get("posts:#{post.id}:field_with_validation")).not_to eq("foobar")
          expect(post.errors.empty?).not_to be_truthy
          expect(post.errors[:field_with_validation]).to eq(["foobar error"])
        end
      end
    end
  end

  context "CustomIdField" do
    let(:custom_id_field) { CustomIdField.create(:uuid => 123) }

    it "should use the custom id correctly" do
      expect(CustomIdField.instance_variable_get(:@ssdb_attr_id_field)).to eq(:uuid)
      expect(custom_id_field.send(:ssdb_attr_key, "content")).to eq("custom_id_fields:123:content")
    end
  end

  context "CustomPoolName" do

    it "should respond to methods" do
      expect(CustomPoolName).to respond_to(:ssdb_attr_pool)
    end

    it "should set SSDBAttr connection for class correct" do
      expect(CustomPoolName.ssdb_attr_pool_name).to eq(:foo_pool)
    end

    describe ".ssdb_attr_pool" do
      it do
        ccn = CustomPoolName.new

        pool_dbl = double(ConnectionPool)

        expect(SSDBAttr).to receive(:pool).with(:foo_pool).and_return(pool_dbl)
        expect(ccn.send(:ssdb_attr_pool)).to eq(pool_dbl)
      end
    end
  end
end
