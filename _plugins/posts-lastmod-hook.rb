#!/usr/bin/env ruby
#
# Check for changed posts

Jekyll::Hooks.register :posts, :post_init do |post|

  # --follow keeps history across renames
  commits = `git log --follow --format=%ad --date=iso -- "#{ post.path }"`.lines

  if commits.length > 1
    post.data['last_modified_at'] = commits.first.strip
  end

end
