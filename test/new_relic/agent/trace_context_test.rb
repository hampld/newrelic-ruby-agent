# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path '../../../test_helper', __FILE__
require 'new_relic/agent/trace_context'
require 'new_relic/agent/distributed_trace_payload'

module NewRelic
  module Agent
    class TraceContextTest < Minitest::Test
      def test_insert
        carrier = {}
        trace_id = 'a8e67265afe2773a3c611b94306ee5c2'
        parent_id = 'fb1010463ea28a38'
        trace_flags = 0x1
        trace_state = 'k1=asdf,k2=qwerty'

        TraceContext.insert carrier: carrier,
                            trace_id: trace_id,
                            parent_id: parent_id,
                            trace_flags: trace_flags,
                            trace_state: trace_state

        assert_equal "00-#{trace_id}-#{parent_id}-01", carrier['traceparent']
        assert_equal trace_state, carrier['tracestate']
      end

      def test_parse
        @config = {
          :account_id => "190",
          :primary_application_id => "46954"
        }

        NewRelic::Agent.config.add_config_for_testing(@config)

        payload = nil

        in_transaction "test_txn" do |txn|
          payload = DistributedTracePayload.for_transaction txn
        end

        carrier = {
          'traceparent' => '00-a8e67265afe2773a3c611b94306ee5c2-fb1010463ea28a38-01',
          'tracestate'  => "123456@nr=#{payload.http_safe},other=asdf"
        }

        tracecontext_data = TraceContext.parse format: TraceContext::TextMapFormat,
                                               carrier: carrier

        traceparent = tracecontext_data.traceparent

        assert_equal '00', traceparent['version']
        assert_equal 'a8e67265afe2773a3c611b94306ee5c2', traceparent['trace_id']
        assert_equal 'fb1010463ea28a38', traceparent['parent_id']
        assert_equal '01', traceparent['trace_flags']

        assert_equal '123456', tracecontext_data.tenant_id
        assert_equal payload.text, tracecontext_data.tracestate_entry.text
        assert_equal ['other=asdf'], tracecontext_data.tracestate
      end
    end
  end
end
