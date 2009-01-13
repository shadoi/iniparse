require File.dirname(__FILE__) + '/spec_helper'

describe 'a Line', :shared => true do
  describe 'when initialized' do
    it 'should use the default options if an empty hash is given' do
      @klass.new(*@klass_args).opts.should     == Line.default_opts
      @klass.new(*@klass_args + [{}]).opts.should == Line.default_opts
    end

    it 'should apply custom options if any are given' do
      @klass.new(*@klass_args + [{:comment_offset => 4}]).opts.should \
        == Line.default_opts.merge(:comment_offset => 4)
    end
  end
end

describe "IniParse::Lines::Line" do
  Line = IniParse::Lines::Line

  before(:all) { @klass = IniParse::Lines::Line; @klass_args = [] }
  it_should_behave_like 'a Line'

  describe '#to_ini' do
    it 'should return an empty string' do
      Line.new.to_ini.should == ''
    end

    it 'should preserve line indents' do
      Line.new(:indent => '    ').to_ini.should == '    '
    end

    describe 'when a comment is set' do
      it 'should correctly include the comment' do
        IniParse::Lines::Section.new(
          'section', :comment => 'comment', :comment_sep => ';',
          :comment_offset => 10
        ).to_ini.should == '[section] ; comment'
      end

      it 'should correctly indent the comment' do
        IniParse::Lines::Section.new(
          'section', :comment => 'comment', :comment_sep => ';',
          :comment_offset => 15
        ).to_ini.should == '[section]      ; comment'
      end

      it 'should use ";" as a default comment seperator' do
        IniParse::Lines::Section.new(
          'section', :comment => 'comment'
        ).to_ini.should == '[section] ; comment'
      end

      it 'should use the correct seperator' do
        IniParse::Lines::Section.new(
          'section', :comment => 'comment', :comment_sep => '#'
        ).to_ini.should == '[section] # comment'
      end

      it 'should use the ensure a space is added before the comment seperator' do
        IniParse::Lines::Section.new(
          'section', :comment => 'comment', :comment_sep => ';',
          :comment_offset => 0
        ).to_ini.should == '[section] ; comment'
      end

      it 'should not add an extra space if the line is blank' do
        Line.new(
          :comment => 'comment', :comment_sep => ';', :comment_offset => 0
        ).to_ini.should == '; comment'
      end
    end

    describe 'when no comment is set' do
      it 'should not add trailing space if :comment_offset has a value' do
        Line.new(:comment_offset => 10).to_ini.should == ''
      end

      it 'should not add a comment seperator :comment_sep has a value' do
        Line.new(:comment_sep => ';').to_ini.should == ''
      end
    end
  end

  describe '#has_comment?' do
    it 'should return true if :comment has a non-blank value' do
      Line.new(:comment => 'comment').should have_comment
    end

    it 'should return true if :comment has a blank value' do
      Line.new(:comment => '').should have_comment
    end

    it 'should return false if :comment has a nil value' do
      Line.new.should_not have_comment
      Line.new(:comment => nil).should_not have_comment
    end
  end

  describe '.parse' do
    it 'should raise NotImplementedError' do
      lambda { Line.parse('', {}) }.should raise_error(NotImplementedError)
    end
  end
end

#
# Section
#

describe 'IniParse::Lines::Section' do
  before(:each) { @section = IniParse::Lines::Section.new('a section') }

  before(:all) { @klass = IniParse::Lines::Section; @klass_args = ['s'] }
  it_should_behave_like 'a Line'

  it 'should respond_to +lines+' do
    @section.should respond_to(:lines)
  end

  it 'should not respond_to +lines=+' do
    @section.should_not respond_to(:lines=)
  end

  it 'should include Enumerable' do
    IniParse::Lines::Section.included_modules.should include(Enumerable)
  end

  describe '#initialize' do
    it 'should typecast the given key to a string' do
      IniParse::Lines::Section.new(:symbol).key.should == 'symbol'
    end
  end

  describe '#option' do
    it 'should retrieve the line identified by the given key' do
      option = IniParse::Lines::Option.new('k', 'value one')
      @section.lines << option
      @section.option('k').should == option
    end

    it 'should return nil if the given key does not exist' do
      @section.option('does_not_exist').should be_nil
    end
  end

  describe '#each' do
    it 'should call #each on +lines+' do
      @section.lines.should_receive(:each)
      @section.each { |l| }
    end
  end

  describe '#[]' do
    it 'should return nil if the given key does not exist' do
      @section['k'].should be_nil
    end

    it 'should return a value if the given key exists' do
      @section.lines << IniParse::Lines::Option.new('k', 'v')
      @section['k'].should == 'v'
    end

    it 'should return an array of values if the key is a duplicate' do
      @section.lines << IniParse::Lines::Option.new('k', 'v1')
      @section.lines << IniParse::Lines::Option.new('k', 'v2')
      @section.lines << IniParse::Lines::Option.new('k', 'v3')
      @section['k'].should == ['v1', 'v2', 'v3']
    end

    it 'should typecast the key to a string' do
      @section.lines << IniParse::Lines::Option.new('k', 'v')
      @section[:k].should == 'v'
    end
  end

  describe '#[]=' do
    it 'should add a new Option with the given key and value' do
      @section['k'] = 'a value'
      @section.option('k').should be_kind_of(IniParse::Lines::Option)
      @section['k'].should == 'a value'
    end

    it 'should update the Option if one already exists' do
      @section.lines << IniParse::Lines::Option.new('k', 'orig value')
      @section['k'] = 'new value'
      @section['k'].should == 'new value'
    end

    it 'should replace the existing Option if it is an array' do
      @section.lines << IniParse::Lines::Option.new('k', 'v1')
      @section.lines << IniParse::Lines::Option.new('k', 'v2')
      @section['k'] = 'new value'
      @section.option('k').should be_kind_of(IniParse::Lines::Option)
      @section['k'].should == 'new value'
    end

    it 'should typecast the key to a string' do
      @section[:k] = 'a value'
      @section['k'].should == 'a value'
    end
  end

  describe '#merge!' do
    before(:each) do
      @section.lines << IniParse::Lines::Option.new('a', 'val1')
      @section.lines << IniParse::Lines::Blank.new
      @section.lines << IniParse::Lines::Comment.new
      @section.lines << IniParse::Lines::Option.new('b', 'val2')

      @new_section = IniParse::Lines::Section.new('new section')
    end

    it 'should merge options from the given Section into the receiver' do
      @new_section.lines << IniParse::Lines::Option.new('c', 'val3')
      @new_section.lines << IniParse::Lines::Option.new('d', 'val4')

      @section.merge!(@new_section)
      @section['a'].should == 'val1'
      @section['b'].should == 'val2'
      @section['c'].should == 'val3'
      @section['d'].should == 'val4'
    end

    it 'should handle duplicates' do
      @new_section.lines << IniParse::Lines::Option.new('a', 'val2')
      @section.merge!(@new_section)
      @section['a'].should == ['val1', 'val2']
    end

    it 'should handle duplicates on both sides' do
      @section.lines << IniParse::Lines::Option.new('a', 'val2')
      @new_section.lines << IniParse::Lines::Option.new('a', 'val3')
      @new_section.lines << IniParse::Lines::Option.new('a', 'val4')

      @section.merge!(@new_section)
      @section['a'].should == ['val1', 'val2', 'val3', 'val4']
    end

    it 'should copy blank lines' do
      @new_section.lines << IniParse::Lines::Blank.new
      @section.merge!(@new_section)
      line = nil
      @section.each(true) { |l| line = l }
      line.should be_kind_of(IniParse::Lines::Blank)
    end

    it 'should copy comments' do
      @new_section.lines << IniParse::Lines::Comment.new
      @section.merge!(@new_section)
      line = nil
      @section.each(true) { |l| line = l }
      line.should be_kind_of(IniParse::Lines::Comment)
    end
  end

  describe '#to_ini' do
    it 'should include the section key' do
      IniParse::Lines::Section.new('a section').to_ini.should == '[a section]'
    end

    it 'should include lines belonging to the section' do
      @section.lines << IniParse::Lines::Option.new('a', 'val1')
      @section.lines << IniParse::Lines::Blank.new
      @section.lines << IniParse::Lines::Comment.new(
        :comment => 'my comment', :comment_sep => ';', :comment_offset => 0
      )
      @section.lines << IniParse::Lines::Option.new('b', 'val2')

      @section.to_ini.should == <<-INI.margin
        [a section]
        a = val1

        ; my comment
        b = val2
      INI
    end

    it 'should include duplicate lines' do
      @section.lines << IniParse::Lines::Option.new('a', 'val1')
      @section.lines << IniParse::Lines::Option.new('a', 'val2')

      @section.to_ini.should == <<-INI.margin
        [a section]
        a = val1
        a = val2
      INI
    end
  end

  describe '#has_option?' do
    before do
      @section['first'] = 'value'
    end

    it 'should return true if an option with the given key exists' do
      @section.should have_option('first')
    end

    it 'should return true if no option with the given key exists' do
      @section.should_not have_option('second')
    end
  end
end

#
# Option
#

describe 'Iniparse::Lines::Option' do
  before(:all) { @klass = IniParse::Lines::Option; @klass_args = ['k', 'v'] }
  it_should_behave_like 'a Line'

  describe '#initialize' do
    it 'should typecast the given key to a string' do
      IniParse::Lines::Option.new(:symbol, '').key.should == 'symbol'
    end
  end

  describe '#to_ini' do
    it 'should include the key and value' do
      IniParse::Lines::Option.new('key', 'value').to_ini.should == 'key = value'
    end
  end

  describe '.parse' do
    def parse(line, opts = {})
      IniParse::Lines::Option.parse(line, opts)
    end

    it 'should typecast empty values to nil' do
      parse('key =').should be_option_tuple('key', nil)
      parse('key = ').should be_option_tuple('key', nil)
      parse('key =    ').should be_option_tuple('key', nil)
    end

    it 'should typecast "true" to TrueClass' do
      parse('key = true').should be_option_tuple('key', true)
      parse('key = TRUE').should be_option_tuple('key', true)
    end

    it 'should typecast "false" to FalseClass' do
      parse('key = false').should be_option_tuple('key', false)
      parse('key = FALSE').should be_option_tuple('key', false)
    end

    it 'should typecast integer values to Integer' do
      parse('key = 1').should be_option_tuple('key', 1)
      parse('key = 10').should be_option_tuple('key', 10)
    end

    it 'should not typecast integers with a leading 0 to Integer' do
      parse('key = 0700').should be_option_tuple('key', '0700')
    end

    it 'should typecast negative integer values to Integer' do
      parse('key = -1').should be_option_tuple('key', -1)
    end

    it 'should typecast float values to Float' do
      parse('key = 3.14159265').should be_option_tuple('key', 3.14159265)
    end

    it 'should typecast negative float values to Float' do
      parse('key = -3.14159265').should be_option_tuple('key', -3.14159265)
    end

    it 'should typecast scientific notation numbers to Float' do
      parse('key = 10e5').should be_option_tuple('key', 10e5)
      parse('key = 10e+5').should be_option_tuple('key', 10e5)
      parse('key = 10e-5').should be_option_tuple('key', 10e-5)

      parse('key = -10e5').should be_option_tuple('key', -10e5)
      parse('key = -10e+5').should be_option_tuple('key', -10e5)
      parse('key = -10e-5').should be_option_tuple('key', -10e-5)

      parse('key = 3.14159265e5').should be_option_tuple('key', 3.14159265e5)
      parse('key = 3.14159265e+5').should be_option_tuple('key', 3.14159265e5)
      parse('key = 3.14159265e-5').should be_option_tuple('key', 3.14159265e-5)

      parse('key = -3.14159265e5').should be_option_tuple('key', -3.14159265e5)
      parse('key = -3.14159265e+5').should be_option_tuple('key', -3.14159265e5)
      parse('key = -3.14159265e-5').should be_option_tuple('key', -3.14159265e-5)
    end
  end
end

#
# Blank
#

describe 'IniParse::Lines::Blank' do
  before(:all) { @klass = IniParse::Lines::Blank; @klass_args = [] }
  it_should_behave_like 'a Line'
end

#
# Comment
#

describe 'IniParse::Lines::Comment' do
  before(:all) { @klass = IniParse::Lines::Comment; @klass_args = [] }
  it_should_behave_like 'a Line'

  describe '#has_comment?' do
    it 'should return true if :comment has a non-blank value' do
      IniParse::Lines::Comment.new(:comment => 'comment').should have_comment
    end

    it 'should return true if :comment has a blank value' do
      IniParse::Lines::Comment.new(:comment => '').should have_comment
    end

    it 'should return true if :comment has a nil value' do
      IniParse::Lines::Comment.new.should have_comment
      IniParse::Lines::Comment.new(:comment => nil).should have_comment
    end
  end

  describe '#to_ini' do
    it 'should return the comment' do
      IniParse::Lines::Comment.new(
        :comment => 'a comment'
      ).to_ini.should == '; a comment'
    end

    it 'should preserve comment offset' do
      IniParse::Lines::Comment.new(
        :comment => 'a comment', :comment_offset => 10
      ).to_ini.should == '          ; a comment'
    end

    it 'should return just the comment_sep if the comment is blank' do
      IniParse::Lines::Comment.new.to_ini.should == ';'
    end
  end
end
