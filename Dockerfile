# Use the official Ruby 1.9 image
FROM ruby:1.9

# Set the working directory in the container
WORKDIR /app

# Copy the Gemfile and Gemfile.lock into the container
COPY Gemfile Gemfile.lock ./

# Install dependencies
RUN bundle install

# Copy the rest of the application code into the container
COPY . .

# Start the application
CMD ["ruby", "script.rb"]
