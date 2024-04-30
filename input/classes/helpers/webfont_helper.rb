# rubocop:disable Style/FrozenStringLiteralComment

# have a look at doc/print/index.md for explanation

module WebfontHelper
  FONTS = {
    #--FONT_NAME => [prefix_name, contains_italic_variant]--#
    "Lato" => ["lato-v11", true],
    "Noto Sans" => ["noto-sans-v6", true],
    "Noto Serif" => ["noto-serif-v4", true],
    "Open Sans" => ["open-sans-v13", true],
    "Oswald" => ["oswald-v11", false],
    "PT Sans" => ["pt-sans-v8", true],
    "PT Sans Narrow" => ["pt-sans-narrow-v7", false],
    "PT Serif" => ["pt-serif-v8", true],
    "Roboto" => ["roboto-v15", true],
    "Roboto Condensed" => ["roboto-condensed-v13", true],
    "Roboto Mono" => ["roboto-mono-v4", true],
    "Roboto Slab" => ["roboto-slab-v6", false]
  }.freeze

  STYLES = %w[normal italic].freeze
  WEIGHTS = %w[normal bold].freeze

  EXTRA = {
    #--FONT_NAME => [[file_name, weight, style],...]--#
    "Open Sans" => [
      ["OpenSans-Light", 300, :normal],
      ["OpenSans-LightItalic", 300, :italic],
      ["OpenSans-Semibold", 600, :normal],
      ["OpenSans-SemiboldItalic", 600, :italic],
      ["OpenSans-ExtraBold", 800, :normal],
      ["OpenSans-ExtraBoldItalic", 800, :italic]
    ],
    "Lato" => [
      ["Lato-Hairline", 100, :normal],
      ["Lato-HairlineItalic", 100, :normal],
      ["Lato-Light", 300, :normal],
      ["Lato-LightItalic", 300, :normal]
    ]
  }.freeze

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
  def generate_webfonts(absolute = false)
    base = base_url(absolute)
    # TODO: rewrite this thing not to use the string
    result = ""
    FONTS.each do |name, prefix|
      STYLES.each do |style|
        next if style == "italic" && !prefix[1] # means_italic_missing

        WEIGHTS.each do |weight|
          variant = font_variant(weight, style)
          result << %(
            @font-face {
              font-family: '#{name}';
              font-style: #{style};
              font-weight: #{weight};
              src:
                url('#{base}#{font_path("SIL/#{prefix[0]}-latin-#{variant}.woff2")}') format('woff2'),
                url('#{base}#{font_path("SIL/#{prefix[0]}-latin-#{variant}.woff")}') format('woff');
            }
          )
        end
      end
    end

    EXTRA.each do |name, extra|
      extra.each do |file_name, weight, style|
        result << %(
          @font-face {
            font-family: '#{name}';
            font-style: #{style};
            font-weight: #{weight};
            src:
              url('#{base}#{font_path("EXTRA/#{file_name}.woff2")}') format('woff2'),
              url('#{base}#{font_path("EXTRA/#{file_name}.woff")}') format('woff');
          }
        )
      end
    end

    raw(result)
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

  private

  def base_url(absolute)
    return "" unless absolute

    "#{request.env['HTTPS'] == 'on' ? 'https://' : 'http://'}#{request.env['HTTP_HOST']}"
  end

  def font_variant(weight, style)
    if weight == "normal" && style == "normal"
      "regular"
    else
      weight = weight == "normal" ? "" : "700"
      style = style == "normal" ? "" : style
      "#{weight}#{style}"
    end
  end
end

# rubocop:enable Style/FrozenStringLiteralComment
