RSpec.describe "Using the legacy should syntax" do
  include_context "with syntax", [:should, :expect]

  describe "#stub" do
    it "supports options" do
      double.stub(:foo, :expected_from => "bar")
    end

    it 'returns `nil` from all terminal actions to discourage further configuration' do
      expect(double.stub(:foo).and_return(1)).to be_nil
      expect(double.stub(:foo).and_raise("boom")).to be_nil
      expect(double.stub(:foo).and_throw(:foo)).to be_nil
    end
  end

  describe "#should_receive" do
    context "with an options hash" do
      it "reports the file and line submitted with :expected_from" do
        begin
          mock = RSpec::Mocks::Double.new("a mock")
          mock.should_receive(:message, :expected_from => "/path/to/blah.ext:37")
          verify mock
        rescue Exception => e
        ensure
          expect(e.backtrace.to_s).to match(/\/path\/to\/blah.ext:37/m)
        end
      end

      it "uses the message supplied with :message" do
        expect {
          m = RSpec::Mocks::Double.new("a mock")
          m.should_receive(:message, :message => "recebi nada")
          verify m
        }.to raise_error("recebi nada")
      end

      it "uses the message supplied with :message after a similar stub" do
        expect {
          m = RSpec::Mocks::Double.new("a mock")
          m.stub(:message)
          m.should_receive(:message, :message => "from mock")
          verify m
        }.to raise_error("from mock")
      end
    end
  end

  describe "#should_not_receive" do
    it "returns a negative message expectation" do
      expect(Object.new.should_not_receive(:foobar)).to be_negative
    end
  end

  describe "#any_instance" do
    let(:klass) do
      Class.new do
        def existing_method; :existing_method_return_value; end
        def existing_method_with_arguments(arg_one, arg_two = nil); :existing_method_with_arguments_return_value; end
        def another_existing_method; end
        private
        def private_method; :private_method_return_value; end
      end
    end

    it "adds an class to the current space" do
      expect {
        klass.any_instance
      }.to change { RSpec::Mocks.space.any_instance_recorders.size }.by(1)
    end

    context "invocation order" do
      describe "#stub" do
        it "raises an error if 'stub' follows 'with'" do
          expect { klass.any_instance.with("1").stub(:foo) }.to raise_error(NoMethodError)
        end

        it "raises an error if 'with' follows 'and_return'" do
          expect { klass.any_instance.stub(:foo).and_return(1).with("1") }.to raise_error(NoMethodError)
        end

        it "raises an error if 'with' follows 'and_raise'" do
          expect { klass.any_instance.stub(:foo).and_raise(1).with("1") }.to raise_error(NoMethodError)
        end

        it "raises an error if 'with' follows 'and_yield'" do
          expect { klass.any_instance.stub(:foo).and_yield(1).with("1") }.to raise_error(NoMethodError)
        end

        context "behaves as 'every instance'" do
          let(:super_class) { Class.new { def foo; 'bar'; end } }
          let(:sub_class)   { Class.new(super_class) }

          it 'handles `unstub` on subclasses' do
            super_class.any_instance.stub(:foo)
            sub_class.any_instance.stub(:foo)
            sub_class.any_instance.unstub(:foo)
            expect(sub_class.new.foo).to eq("bar")
          end
        end
      end

      describe "#stub_chain" do
        it "raises an error if 'stub_chain' follows 'and_return'" do
          expect { klass.any_instance.and_return("1").stub_chain(:foo, :bar) }.to raise_error(NoMethodError)
        end

        context "allows a chain of methods to be stubbed using #stub_chain" do
          example "given symbols representing the methods" do
            klass.any_instance.stub_chain(:one, :two, :three).and_return(:four)
            expect(klass.new.one.two.three).to eq(:four)
          end

          example "given a hash as the last argument uses the value as the expected return value" do
            klass.any_instance.stub_chain(:one, :two, :three => :four)
            expect(klass.new.one.two.three).to eq(:four)
          end

          example "given a string of '.' separated method names representing the chain" do
            klass.any_instance.stub_chain('one.two.three').and_return(:four)
            expect(klass.new.one.two.three).to eq(:four)
          end
        end
      end

      describe "#should_receive" do
        it "raises an error if 'should_receive' follows 'with'" do
          expect { klass.any_instance.with("1").should_receive(:foo) }.to raise_error(NoMethodError)
        end
      end

      describe "#should_not_receive" do
        it "fails if the method is called" do
          klass.any_instance.should_not_receive(:existing_method)
          expect { klass.new.existing_method }.to raise_error(RSpec::Mocks::MockExpectationError)
        end

        it "passes if no method is called" do
          expect { klass.any_instance.should_not_receive(:existing_method) }.to_not raise_error
        end

        it "passes if only a different method is called" do
          klass.any_instance.should_not_receive(:existing_method)
          expect { klass.new.another_existing_method }.to_not raise_error
        end

        context "with constraints" do
          it "fails if the method is called with the specified parameters" do
            klass.any_instance.should_not_receive(:existing_method_with_arguments).with(:argument_one, :argument_two)
            expect {
              klass.new.existing_method_with_arguments(:argument_one, :argument_two)
            }.to raise_error(RSpec::Mocks::MockExpectationError)
          end

          it "passes if the method is called with different parameters" do
            klass.any_instance.should_not_receive(:existing_method_with_arguments).with(:argument_one, :argument_two)
            expect { klass.new.existing_method_with_arguments(:argument_three, :argument_four) }.to_not raise_error
          end
        end

        context 'when used in combination with should_receive' do
          it 'passes if only the expected message is received' do
            klass.any_instance.should_receive(:foo)
            klass.any_instance.should_not_receive(:bar)
            klass.new.foo
            verify_all
          end
        end

        it "prevents confusing double-negative expressions involving `never`" do
          expect {
            klass.any_instance.should_not_receive(:not_expected).never
          }.to raise_error(/trying to negate it again/)
        end
      end

      describe "#unstub" do
        it "replaces the stubbed method with the original method" do
          klass.any_instance.stub(:existing_method)
          klass.any_instance.unstub(:existing_method)
          expect(klass.new.existing_method).to eq(:existing_method_return_value)
        end

        it "removes all stubs with the supplied method name" do
          klass.any_instance.stub(:existing_method).with(1)
          klass.any_instance.stub(:existing_method).with(2)
          klass.any_instance.unstub(:existing_method)
          expect(klass.new.existing_method).to eq(:existing_method_return_value)
        end

        it "removes stubs even if they have already been invoked" do
          klass.any_instance.stub(:existing_method).and_return(:any_instance_value)
          obj = klass.new
          obj.existing_method
          klass.any_instance.unstub(:existing_method)
          expect(obj.existing_method).to eq(:existing_method_return_value)
        end

        it "removes stubs from sub class after invokation when super class was originally stubbed" do
          klass.any_instance.stub(:existing_method).and_return(:any_instance_value)
          obj = Class.new(klass).new
          expect(obj.existing_method).to eq(:any_instance_value)
          klass.any_instance.unstub(:existing_method)
          expect(obj.existing_method).to eq(:existing_method_return_value)
        end

        it "does not remove any stubs set directly on an instance" do
          klass.any_instance.stub(:existing_method).and_return(:any_instance_value)
          obj = klass.new
          obj.stub(:existing_method).and_return(:local_method)
          klass.any_instance.unstub(:existing_method)
          expect(obj.existing_method).to eq(:local_method)
        end

        it "does not remove any expectations with the same method name" do
          klass.any_instance.should_receive(:existing_method_with_arguments).with(3).and_return(:three)
          klass.any_instance.stub(:existing_method_with_arguments).with(1)
          klass.any_instance.stub(:existing_method_with_arguments).with(2)
          klass.any_instance.unstub(:existing_method_with_arguments)
          expect(klass.new.existing_method_with_arguments(3)).to eq(:three)
        end

        it "raises a MockExpectationError if the method has not been stubbed" do
          expect {
            klass.any_instance.unstub(:existing_method)
          }.to raise_error(RSpec::Mocks::MockExpectationError, 'The method `existing_method` was not stubbed or was already unstubbed')
        end

        it 'does not get confused about string vs symbol usage for the message' do
          klass.any_instance.stub(:existing_method) { :stubbed }
          klass.any_instance.unstub("existing_method")
          expect(klass.new.existing_method).to eq(:existing_method_return_value)
        end
      end
    end
  end
end

RSpec.context "with default syntax configuration" do
  orig_syntax = nil

  before(:all) { orig_syntax = RSpec::Mocks.configuration.syntax }
  after(:all)  { RSpec::Mocks.configuration.syntax = orig_syntax }
  before       { RSpec::Mocks.configuration.reset_syntaxes_to_default }

  let(:expected_arguments) {
    [
      /Using.*without explicitly enabling/,
      {:replacement=>"the new `:expect` syntax or explicitly enable `:should`"}
    ]
  }

  it "it warns about should once, regardless of how many times it is called" do
    expect(RSpec).to receive(:deprecate).with(*expected_arguments)
    o = Object.new
    o2 = Object.new
    o.should_receive(:bees)
    o2.should_receive(:bees)

    o.bees
    o2.bees
  end

  it "warns about should not once, regardless of how many times it is called" do
    expect(RSpec).to receive(:deprecate).with(*expected_arguments)
    o = Object.new
    o2 = Object.new
    o.should_not_receive(:bees)
    o2.should_not_receive(:bees)
  end

  it "warns about stubbing once, regardless of how many times it is called" do
    expect(RSpec).to receive(:deprecate).with(*expected_arguments)
    o = Object.new
    o2 = Object.new

    o.stub(:faces)
    o2.stub(:faces)
  end

  it "warns about unstubbing once, regardless of how many times it is called" do
    expect(RSpec).to receive(:deprecate).with(/Using.*without explicitly enabling/,
      {:replacement => "`allow(...).to_receive(...).and_call_original` or explicitly enable `:should`"})
    o = Object.new
    o2 = Object.new

    allow(o).to receive(:faces)
    allow(o2).to receive(:faces)

    o.unstub(:faces)
    o2.unstub(:faces)
  end


  it "doesn't warn about stubbing after a reset and setting should" do
    expect(RSpec).not_to receive(:deprecate)
    RSpec::Mocks.configuration.reset_syntaxes_to_default
    RSpec::Mocks.configuration.syntax = :should
    o = Object.new
    o2 = Object.new
    o.stub(:faces)
    o2.stub(:faces)
  end

  it "includes the call site in the deprecation warning" do
    obj = Object.new
    expect_deprecation_with_call_site(__FILE__, __LINE__ + 1)
    obj.stub(:faces)
  end
end

RSpec.context "when the should syntax is enabled on a non-default syntax host" do
  include_context "with the default mocks syntax"

  it "continues to warn about the should syntax" do
    my_host = Class.new
    expect(RSpec).to receive(:deprecate)
    RSpec::Mocks::Syntax.enable_should(my_host)

    o = Object.new
    o.should_receive(:bees)
    o.bees
  end
end
