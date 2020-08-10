# frozen_string_literal: true

require_relative './examples/user'
require_relative './examples/book'

RSpec.describe RuleBox do
  it 'has a version number' do
    expect(RuleBox::VERSION).not_to be nil
  end

  context 'with validators throwing exceptions' do
    before :all do
      RuleBox::Facade.configure do |config|
        config.add_dependency(:hash) do |obj|
          raise 'Must be an Hash' unless obj.is_a?(Hash)
        end
        config.add_dependency(:array) do |obj|
          raise 'Must be an Array' unless obj.is_a?(Array)
        end
      end
    end
    after(:all) { RuleBox::Facade.clear_configuration }

    it 'must generate one error' do
      expect { RuleBox::Facade.new }.to raise_error(RuntimeError)
    end

    it 'must generate one error on first validator' do
      expect { RuleBox::Facade.new(hash: [], array: []) }.to raise_error('Must be an Hash')
    end

    it 'must generate one error on second validator' do
      expect { RuleBox::Facade.new(hash: {}, array: 123_456) }.to raise_error('Must be an Array')
    end
  end

  context 'with validators add errors' do
    before :all do
      RuleBox::Facade.configure do |config|
        config.add_dependency :integer do |obj, errors|
          errors << 'Must pass one Integer' unless obj.is_a?(Integer)
        end
      end
    end
    after(:all) { RuleBox::Facade.clear_configuration }

    it 'with validators add errors' do
      expect { RuleBox::Facade.new(integer: {}, array: 123_456) }.to raise_error('Must pass one Integer')
    end
  end

  context 'add rules to models' do
    context :user do
      let(:errors) { [] }

      before :each do
        RuleBox::Facade.configure do |config|
          config.default_error_message = 'Ops, ocorreu um erro!'
          config.resolver_exception do |error, _facade|
            errors << error.message
          end
        end
      end
      after(:all) { RuleBox::Facade.clear_configuration }

      it 'validate name of user' do
        user = User.new
        user.name = 'Beltrano'
        user.age = 19

        facade = RuleBox::Facade.new
        facade.insert user
        expect(facade.status).to eq(:green)
      end

      it 'must throws error' do
        user = User.new
        user.name = 'name'
        user.age = 19
        user.throws_error = true

        facade = RuleBox::Facade.new
        facade.insert user
        expect(errors.count).to eq(1)
        expect(errors.first).to eq('any thing')
      end

      context 'with dynamic rules' do
        it 'must check one error' do
          user = User.new
          user.name = 'leo'
          user.age = 19

          facade = RuleBox::Facade.new
          facade.check user
          expect(facade.errors.count).to eq(1)
          expect(facade.errors.first).to eq('Nome deve conter pelo menos 4 caracteres')
        end
      end
    end

    context :book do
      let(:current_errors) { [] }

      before :each do
        RuleBox::Facade.configure do |config|
          config.resolver_exception { |error| current_errors << error.message }
          config.add_dependency(:user) do |obj|
            raise 'Must be an User' unless obj.is_a?(User)
          end
        end
      end
      after(:all) { RuleBox::Facade.clear_configuration }

      it 'must validate user is "Leo"' do
        user = User.new
        book = Book.new
        facade = RuleBox::Facade.new(user: user)
        facade.insert book

        expect(facade.status).to eq(:red)
        expect(facade.errors.first).to eq('is not Leo')
        expect(current_errors.empty?).to be_truthy
      end
    end
  end
end
