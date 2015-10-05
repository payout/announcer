RSpec.describe Announcer do
  context '#config' do
    it 'can be set' do
      subject.config { |c|
        c.test_value = 'hello'
      }

      expect(subject.config).to be_an Announcer::Config
      expect(subject.config.test_value).to eq 'hello'
    end
  end
end
