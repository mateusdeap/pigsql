require "strscan"

class Lexer
  KEYWORDS = {
    "SELECT" => :SELECT,
    "FROM" => :FROM,
    "WHERE" => :WHERE,
    "INSERT" => :INSERT,
    "INTO" => :INTO,
    "VALUES" => :VALUES,
    "UPDATE" => :UPDATE,
    "SET" => :SET,
    "DELETE" => :DELETE,
    "CREATE" => :CREATE,
    "TABLE" => :TABLE,
    "DROP" => :DROP,
    "ALTER" => :ALTER,
    "ADD" => :ADD,
    "PRIMARY" => :PRIMARY,
    "KEY" => :KEY,
    "INTEGER" => :INTEGER,
    "VARCHAR" => :VARCHAR,
    "AND" => :AND,
    "OR" => :OR,
    "NOT" => :NOT,
    "NULL" => :NULL
  }.freeze

  OPERATORS = {
    "=" => :EQUALS,
    "<" => :LESS_THAN,
    ">" => :GREATER_THAN,
    "<=" => :LESS_EQUAL,
    ">=" => :GREATER_EQUAL,
    "<>" => :NOT_EQUAL,
    "!=" => :NOT_EQUAL,
    "+" => :PLUS,
    "-" => :MINUS,
    "*" => :MULTIPLY,
    "/" => :DIVIDE
  }.freeze

  PUNCTUATION = {
    "(" => :LPAREN,
    ")" => :RPAREN,
    "," => :COMMA,
    ";" => :SEMICOLON,
    "." => :DOT
  }.freeze

  def initialize(input)
    @scanner = StringScanner.new(input)
    @line = 1
    @column = 1
  end

  def next_token
    skip_whitespace

    return nil if @scanner.eos?

    position = {line: @line, column: @column}

    if token = scan_keyword ||
        scan_identifier ||
        scan_integer ||
        scan_float ||
        scan_string ||
        scan_operator ||
        scan_punctuation
      return token + [position]
    end

    unexpected_char = @scanner.getch
    update_position(unexpected_char)
    [:ERROR, "Unexpected character: #{unexpected_char}", position]
  end

  def tokenize
    tokens = []
    while token = next_token
      tokens << token
      break if token[0] == :ERROR
    end
    tokens
  end

  def skip_whitespace
    while true
      whitespace = @scanner.scan(/[ \t\r\n]+/)
      if whitespace
        update_position(whitespace)
        next
      end

      if @scanner.scan(/--.*$/)
        update_position(@scanner.matched)
        next
      end

      if @scanner.scan(/\/\*.*?\*\//m)
        update_position(@scanner.matched)
        next
      end

      break
    end
  end

  def scan_keyword
    if @scanner.scan(/[A-Za-z_][A-Za-z0-9_]*/)
      matched = @scanner.matched
      upper_matched = matched.upcase

      if KEYWORDS.key?(upper_matched)
        update_position(matched)
        return [KEYWORDS[upper_matched], upper_matched]
      else
        @scanner.unscan
      end
    end
    nil
  end

  def scan_identifier
    if @scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
      matched = @scanner.matched
      update_position(matched)
      return [:IDENTIFIER, matched]
    end

    if @scanner.scan(/"([^"]*)"/)
      matched = @scanner.matched
      value = @scanner[1]
      update_position(matched)
      return [:IDENTIFIER, value]
    end

    nil
  end

  def scan_integer
    if @scanner.scan(/\d+/)
      matched = @scanner.matched
      update_position(matched)
      return [:INTEGER, matched.to_i]
    end
  end

  def scan_float
    if @scanner.scan(/\d+\.\d+/)
      matched = @scanner.matched
      update_position(matched)
      return [:FLOAT, matched.to_f]
    end
  end

  def scan_string
    if @scanner.scan(/'([^']*)'/)
      matched = @scanner.matched
      value = @scanner[1]
      update_position(matched)
      return [:STRING, value]
    end
    nil
  end

  def scan_operator
    OPERATORS.keys.sort_by { |k| -k.length }.each do |op|
      if @scanner.scan(Regexp.new(Regexp.escape(op)))
        matched = @scanner.matched
        update_position(matched)
        return [OPERATORS[op], matched]
      end
    end

    nil
  end

  def scan_punctuation
    PUNCTUATION.each do |char, type|
      if @scanner.scan(Regexp.new(Regexp.escape(char)))
        matched = @scanner.matched
        update_position(matched)
        return [type, matched]
      end
    end

    nil
  end

  def update_position(text)
    lines = text.count("\n")
    if lines > 0
      @line += lines
      @column = text.length - text.rindex("\n") - 1
    else
      @column += text.length
    end
  end
end
