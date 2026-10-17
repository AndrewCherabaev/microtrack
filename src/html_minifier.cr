module HtmlMinifier
  def self.transform(source : String) : String
    styled = replace_block(source, "<style>", "</style>") { |css| minify_style(css) }
    scripted = replace_block(styled, "<script>", "</script>") { |js| minify_script(js) }
    collapse_html(scripted)
  end

  def self.collapse_html(html : String) : String
    html.gsub(/>\s+</, "><").strip
  end

  def self.minify_style(css : String) : String
    without_comments = css.gsub(/\/\*.*?\*\//m, "")
    collapsed = without_comments.gsub(/\s+/, " ")
    tightened = collapsed.gsub(/\s*[{};,]\s*/) { |match| match.gsub(/\s+/, "") }
    tightened.gsub(/;\}/, "}").strip
  end

  def self.minify_script(script : String) : String
    without_blocks = script.gsub(/\/\*.*?\*\//m, "")
    without_blocks.lines
      .reject { |line| line.strip.starts_with?("//") }
      .map(&.strip)
      .reject(&.empty?)
      .join("\n")
  end

  def self.replace_block(source : String, open_tag : String, close_tag : String, &) : String
    start = source.index(open_tag)
    return source unless start
    content_start = start + open_tag.size
    finish = source.index(close_tag, content_start)
    raise "unterminated #{open_tag} block" unless finish
    source[0, content_start] + yield(source[content_start, finish - content_start]) + source[finish, source.size]
  end
end
