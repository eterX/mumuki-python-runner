require 'spec_helper'
require 'mumukit/bridge'

describe 'runner' do
  let(:bridge) { Mumukit::Bridge::Bridge.new('http://localhost:4567') }

  before(:all) do
    @pid = Process.spawn 'rackup -p 4567', err: '/dev/null'
    sleep 3
  end
  after(:all) { Process.kill 'TERM', @pid }

  it 'answers a valid hash when submission is ok' do
    response = bridge.run_tests!(test: 'test(ok) :- foo(X), assertion(1 == X).',
                                 extra: '',
                                 content: 'foo(1).',
                                 expectations: [])

    expect(response).to eq(status: :passed,
                           result: "```\n.\n\n```",
                           expectation_results: [],
                           test_results: [],
                           feedback: '',
                           response_type: :unstructured)
  end

  it 'answers a valid hash when submission is ok but expectations failed' do
    response = bridge.run_tests!(test: 'test(ok) :- foo(X), assertion(1 == X).',
                                 extra: 'foo(1).',
                                 content: '',
                                 expectations: [{inspection: 'HasArity:2', binding: 'foo'}])

    expect(response).to eq(status: :passed_with_warnings,
                           result: "```\n.\n\n```",
                           expectation_results: [binding: 'foo', inspection: 'HasArity:2', result: :failed],
                           test_results: [],
                           feedback:'',
                           response_type: :unstructured)
  end

  it 'answers a valid hash when submission is not ok' do
    response = bridge.
        run_tests!(test: 'test(ok) :- foo(X), assertion(1 == X).',
                   extra: '',
                   content: 'foo(2).',
                   expectations: [{inspection: 'HasBinding', binding: 'foo'}]).
        reject { |k, _v| k == :result }

    expect(response).to eq(status: :failed,
                           expectation_results: [{inspection: 'HasBinding', binding: 'foo', result: :passed}],
                           feedback: '',
                           test_results: [],
                           response_type: :unstructured)
  end


  it 'answers a valid hash when submission hangs' do
    response = bridge.
        run_tests!(test: 'test(ok) :- foo(2).',
                   extra: '',
                   content: 'foo(2) :- foo(2).',
                   expectations: [{inspection: 'HasBinding', binding: 'foo'}])

    expect(response).to eq(status: :aborted,
                           result: "```\nExecution time limit of 4s exceeded. Is your program performing an infinite loop or recursion?\n```",
                           expectation_results: [{inspection: 'HasBinding', binding: 'foo', result: :passed}],
                           feedback: '',
                           test_results: [],
                           response_type: :unstructured)
  end

  it 'answers a valid hash when query is ok' do
    response = bridge.run_query!(extra: 'x = 3',
                                 content: 'y = 6',
                                 query: 'x + y')
    expect(response).to eq(status: :passed, result: '=> 9')
  end

  it 'answers a valid hash when query is not ok' do
    response = bridge.
        run_query!(extra: '',
                   content: '',
                   query: 'foo.bar()')
    expect(response[:status]).to eq(:failed)
  end


  it 'escapes characters' do
    response = bridge.run_tests!(test: 'test(ok) :- foo(X), assertion(1 == X).',
                                 extra: '',
                                 content: 'acontecimiento(x, y) :- x /= 7',
                                 expectations: [{inspection: 'HasBinding', binding: 'foo'}])
    expect(response[:result]).to include('Syntax error: Operator expected')
    expect(response[:feedback]).to be_present
  end


  it 'status => aborted when using an infinite recursion' do
    response = bridge.
        run_query!(extra: '',
                   content: 'recursive(A):-
  recursive(A).',
                   query: 'recursive(1).')
    expect(response[:status]).to eq(:aborted)
    expect(response[:result]).not_to eq('')
  end

end
