#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::View::Drugs::TestPrescription -- oddb.org -- 06.08.2012 -- yasaka@ywesee.com

$: << File.expand_path('../..', File.dirname(__FILE__))
$: << File.expand_path("../../../src", File.dirname(__FILE__))

gem 'minitest'
require 'minitest/autorun'

class TestJavaScript <Minitest::Test
  def test_simple_logging
    assert_equal("testing\n", `nodejs -e "console.log('testing');"`);
  end

  def test_prescription
    javascripts = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..','doc', 'resources', 'javascript'))
    base        = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..','doc', 'resources'))
    outfile      = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data', 'log', 'javascript_test.js'));
    ENV['NODE_PATH']=javascripts # "#{dojo}:#{javascripts}"
    #expected = 'http://2dmedication.org/|1.0|4dd33f59-1fbb-4fc9-96f1-488e7175d761|TriaMed|3.9.3.0|7601000092786|K2345.33||20131104|Beispiel|Susanne|3073|19460801|7601003000382;|2014236||1||0.00-0.00-0.00-0.00|||1|||SPEZIALVERBAND|1|20131214|0.00-0.00-0.00-0.00||40|0|7680456740106|||1||1.00-1.00-1.00-0.00|zu Beginn der Mahlzeiten mit mindestens einem halben Glas Wasser einzunehmen||0;27834'
    expected = "http://2dmedication.org/|1.0|4dd33f59-1fbb-4fc9-96f1-488e7175d761|TriaMed|3.9.3.0||K2345.33||20131104|Beispiel|Susanne|3073|19460801|7601003000382;|2014236||1||0.00-0.00-0.00-0.00|||1|||SPEZIALVERBAND|1|20131214|0.00-0.00-0.00-0.00||40|0|7680456740106|||1||1.00-1.00-1.00-0.00|zu Beginn der Mahlzeiten mit mindestens einem halben Glas Wasser einzunehmen||0;27164"
    # TODO: ist it okay to skip 7601000092786 in expectation?
    cmd = "cat #{javascripts}/prescription.js #{javascripts}/qrcode.js #{__FILE__.sub('.rb','.js')} | tee #{outfile} | nodejs"
    result = `#{cmd}`.chomp
    puts "Failed running #{cmd}" unless expected == result
    assert_equal(expected, `#{cmd}`.chomp);
  end
end

