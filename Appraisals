appraise 'rails-5.0' do
  gem 'rails', '~> 5.0.0'
  if RUBY_VERSION >= '3.4.0'
    gem 'base64'
    gem 'mutex_m'
  end
end

appraise 'rails-5.1' do
  gem 'rails', '~> 5.1.0'
  if RUBY_VERSION >= '3.4.0'
    gem 'base64'
    gem 'mutex_m'
  end
end

appraise 'rails-5.2' do
  gem 'rails', '~> 5.2.0'
  if RUBY_VERSION >= '3.4.0'
    gem 'base64'
    gem 'mutex_m'
  end
end

appraise 'rails-6.0' do
  gem 'rails', '~> 6.0.0'
  if RUBY_VERSION >= '3.4.0'
    gem 'drb'
    gem 'mutex_m'
  end
end

appraise 'rails-6.1' do
  gem 'rails', '~> 6.1.0'
  if RUBY_VERSION >= '3.4.0'
    gem 'drb'
    gem 'mutex_m'
  end
end

if RUBY_VERSION >= '2.7.0'
  appraise 'rails-7.0' do
    gem 'rails', '~> 7.0.0'
    if RUBY_VERSION >= '3.4.0'
      gem 'drb'
      gem 'mutex_m'
    end
  end

  appraise 'rails-7.1' do
    gem 'rails', '~> 7.1.0'
  end
end

if RUBY_VERSION >= '3.1.0'
  appraise 'rails-7.2' do
    gem 'rails', '~> 7.2.0'
  end
end

if RUBY_VERSION >= '3.2.0'
  appraise 'rails-8.0' do
    gem 'rails', '~> 8.0.0'
  end

  appraise 'rails-8.0' do
    gem 'rails', '~> 8.1.0'
  end
end

# Cap nokogiri to older versions, as v1.19.0 current has unresolved incompatibility issues
gem 'nokogiri', '< 1.19.0'
