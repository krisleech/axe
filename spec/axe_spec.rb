require 'spec_helper'

describe Axe do
  it 'has a version number' do
    expect(Axe::VERSION).not_to be nil
  end

  it 'does something useful' do
    app = Axe::App.new
    app.start
  end
end
