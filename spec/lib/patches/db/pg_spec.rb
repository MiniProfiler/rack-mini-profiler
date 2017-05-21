require 'pg'

require './lib/patches/db/pg'

require 'spec_helper'

describe PG::Connection do
  let(:conn) { described_class.open(dbname: 'test') }

  describe '.get_binds' do
    let(:params) { ['id', 'name'] }

    let(:sql) { 'SELECT  1 AS one FROM "my_model" WHERE LOWER("my_model"."name") = LOWER($1) AND ("my_model"."id" != $2) LIMIT $3' }

    let(:args) { [sql, params] }

    it 'should work' do
      expect { conn.get_binds(args) }.not_to raise_error
    end
  end
end
