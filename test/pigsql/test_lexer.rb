require "minitest/autorun"
require "pigsql/lexer"

class TestLexer < Minitest::Test
  def test_empty_input
    lexer = Lexer.new("")
    assert_nil lexer.next_token, "Empty input should return nil token"
  end

  def test_whitespace_handling
    lexer = Lexer.new("   \n\t  ")
    assert_nil lexer.next_token, "Whitespace-only input should return nil after skipping"
  end

  # Test individual token types
  def test_keywords
    # Test each keyword with variations in case
    Lexer::KEYWORDS.each do |keyword, token_type|
      [keyword, keyword.downcase, keyword.capitalize].each do |variant|
        lexer = Lexer.new(variant)
        token, value, position = lexer.next_token

        assert_equal token_type, token
        assert_equal keyword, value
        assert_equal 1, position[:line]
        assert_equal 1, position[:column]
      end
    end
  end

  def test_identifiers
    # Regular identifiers
    identifiers = ["table_name", "column1", "user_id_123", "_private"]

    identifiers.each do |identifier|
      lexer = Lexer.new(identifier)
      token, value, _ = lexer.next_token

      assert_equal :IDENTIFIER, token
      assert_equal identifier, value
    end

    # Quoted identifiers
    lexer = Lexer.new('"Quoted Column"')
    token, value, _ = lexer.next_token

    assert_equal :IDENTIFIER, token
    assert_equal "Quoted Column", value
  end

  def test_integers
    lexer = Lexer.new("123")
    token, value, _ = lexer.next_token

    assert_equal :INTEGER, token
    assert_equal 123, value
  end

  def test_floats
    lexer = Lexer.new("123.45")
    token, value, _ = lexer.next_token

    assert_equal :FLOAT, token
    assert_equal 123.45, value
  end

  def test_strings
    lexer = Lexer.new("'This is a string'")
    token, value, _ = lexer.next_token

    assert_equal :STRING, token
    assert_equal "This is a string", value
  end

  def test_operators
    Lexer::OPERATORS.each do |op_text, op_type|
      lexer = Lexer.new(op_text)
      token, value, _ = lexer.next_token

      assert_equal op_type, token
      assert_equal op_text, value
    end
  end

  def test_punctuation
    Lexer::PUNCTUATION.each do |punct_text, punct_type|
      lexer = Lexer.new(punct_text)
      token, value, _ = lexer.next_token

      assert_equal punct_type, token
      assert_equal punct_text, value
    end
  end

  def test_complex_sql
    sql = "SELECT id, name FROM users WHERE age > 18;"
    lexer = Lexer.new(sql)

    # Expected tokens for this SQL
    expected = [
      [:SELECT, "SELECT"],
      [:IDENTIFIER, "id"],
      [:COMMA, ","],
      [:IDENTIFIER, "name"],
      [:FROM, "FROM"],
      [:IDENTIFIER, "users"],
      [:WHERE, "WHERE"],
      [:IDENTIFIER, "age"],
      [:GREATER_THAN, ">"],
      [:INTEGER, 18],
      [:SEMICOLON, ";"]
    ]

    expected.each_with_index do |exp, i|
      exp_token, exp_value = exp
      token, value, _ = lexer.next_token

      assert_equal exp_token, token, "Token type mismatch at position #{i}"
      assert_equal exp_value, value, "Token value mismatch at position #{i}"
    end

    # No more tokens should be available
    assert_nil lexer.next_token
  end

  def test_comments
    # Single line comment
    lexer = Lexer.new("-- This is a comment\nSELECT *")
    token, value, position = lexer.next_token

    assert_equal :SELECT, token
    assert_equal "SELECT", value
    assert_equal 2, position[:line] # Should be on line 2 after the comment

    # Multi-line comment
    lexer = Lexer.new("/* This is a\nmulti-line comment */\nSELECT *")
    token, value, position = lexer.next_token

    assert_equal :SELECT, token
    assert_equal "SELECT", value
    assert_equal 3, position[:line] # Should be on line 3 after the comment
  end

  def test_error_handling
    lexer = Lexer.new("SELECT @ FROM table")

    # First token should be SELECT
    token, _, _ = lexer.next_token
    assert_equal :SELECT, token

    # Second token should be an error for the @ character
    token, value, _ = lexer.next_token
    assert_equal :ERROR, token
    assert_match(/Unexpected character/, value)
  end

  def test_position_tracking
    sql = "SELECT\nname\nFROM users"
    lexer = Lexer.new(sql)

    # SELECT at line 1, column 1
    _, _, position = lexer.next_token
    assert_equal 1, position[:line]
    assert_equal 1, position[:column]

    # name at line 2, column 1
    _, _, position = lexer.next_token
    assert_equal 2, position[:line]
    assert_equal 1, position[:column]

    # FROM at line 3, column 1
    _, _, position = lexer.next_token
    assert_equal 3, position[:line]
    assert_equal 1, position[:column]

    # users at line 3, column 6
    _, _, position = lexer.next_token
    assert_equal 3, position[:line]
    assert_equal 6, position[:column]
  end

  # Test the public methods directly
  def test_update_position
    lexer = Lexer.new("")

    # Test simple text
    lexer.update_position("test")
    assert_equal 1, lexer.instance_variable_get(:@line)
    assert_equal 5, lexer.instance_variable_get(:@column)

    # Test with newlines
    lexer.update_position("line1\nline2\nline3")
    assert_equal 3, lexer.instance_variable_get(:@line)
    assert_equal 5, lexer.instance_variable_get(:@column)
  end

  def test_skip_whitespace
    # Test skipping spaces
    lexer = Lexer.new("   SELECT")
    lexer.skip_whitespace
    assert_equal "SELECT", lexer.instance_variable_get(:@scanner).rest

    # Test skipping comment
    lexer = Lexer.new("-- Comment\nSELECT")
    lexer.skip_whitespace
    assert_equal "SELECT", lexer.instance_variable_get(:@scanner).rest

    # Test skipping multi-line comment
    lexer = Lexer.new("/* Multi-line\nComment */SELECT")
    lexer.skip_whitespace
    assert_equal "SELECT", lexer.instance_variable_get(:@scanner).rest
  end

  def test_tokenize_method
    sql = "SELECT * FROM table;"
    lexer = Lexer.new(sql)

    tokens = lexer.tokenize
    assert_equal 5, tokens.size # SELECT, *, FROM, table, ;

    # Test that tokenize stops on error
    sql_with_error = "SELECT @ FROM table;"
    lexer = Lexer.new(sql_with_error)

    tokens = lexer.tokenize
    assert_equal 2, tokens.size # SELECT, ERROR
    assert_equal :ERROR, tokens.last[0]
  end
end
