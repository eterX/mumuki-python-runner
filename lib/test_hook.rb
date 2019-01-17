class PythonTestHook < Mumukit::Templates::FileHook
  isolated true

  def tempfile_extension
    '.py'
  end

  def command_line(filename)
    "python #{filename}"
  end

  def compile_file_content(request)
    <<python
import unittest
import xmlrunner
import sys

#{request.content}
#{request.extra}
#{test_class(request.test)}

unittest.main(
  testRunner=xmlrunner.XMLTestRunner(output=sys.__stdout__),
  failfast=False,
  buffer=False,
  catchbreak=False
)
python
  end

  def post_process_file(_file, output, status)
    xml = output.split("Generating XML reports...\n").last

    report = Nokogiri::XML(xml)
    test_results = generate_test_results report

    [test_results, status]
  rescue
    [result, :errored]
  end

  private

  def test_class(test)
    return test if test =~ /class.*\( *unittest.TestCase *\) *:/
    <<python
class MumukiTest(unittest.TestCase):
  #{test.gsub(/\n/,"\n\t")}
python
  end

  def generate_test_results(report)
    report.xpath('//testcase').map {|test_case|
      error = test_case.xpath('failure').attribute('message')

      [
        format_test_name(test_case.attribute('name').to_s),
        error.nil? ? :passed: :failed,
        error.to_s
      ]
    }
  end

  def format_test_name(name)
    name.sub('test_', '').gsub('_', ' ').capitalize
  end
end

