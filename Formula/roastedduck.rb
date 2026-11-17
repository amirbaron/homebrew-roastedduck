require "shellwords"

class Roastedduck < Formula
  desc "Analytical SQL engine in Rust with bundled DuckDB-compatible extensions"
  homepage "https://amirbaron.github.io/roastedDuck/"
  version "1.5.6.post4"
  license "MIT"

  bottle do
    root_url "https://github.com/amirbaron/homebrew-roastedduck/releases/download/v1.5.6.post4"
    sha256 cellar: :any_skip_relocation, arm64_linux: "5c67f24df8c899267d64af6d9bc132418f4aeb8cced2cd08c7111ab92f740988"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "76db48a14a87b0c276281c63c159cba5f46f72256a11e303a001cbfef358b7a0"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "ac4ddf3e00101ac51745bef055b2db2815f1614f3e1db15f543ef050c4ae45db"
  end

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :big_sur
    url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post4/roastedduck-1.5.6.post4-macos-arm64.tar.gz"
    sha256 "4c2b65d147d394f1532edc87c14fe3e1853760f88d8370232153424f2756cd09"
  end

  on_linux do
    on_arm do
      url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post4/roastedduck-1.5.6.post4-linux-arm64.tar.gz"
      sha256 "19293a5c096d6ce772ad5708db47cc26fbfc60269756968670794a13bc7c08aa"
    end
    on_intel do
      url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post4/roastedduck-1.5.6.post4-linux-amd64.tar.gz"
      sha256 "479519e670184da49e4f8b640b3bd65c542a8551c2f767da4d81ca155563be43"
    end
  end

  def install
    bin.install "bin/roastedDuck" => "roastedduck"
    bin.install_symlink "roastedduck" => "roastedDuck" unless (bin/"roastedDuck").exist?
    pkgshare.install "notices", "LICENSE", "THIRD_PARTY_NOTICES.md"
  end

  def caveats
    <<~EOS
      httpfs, aws, azure, icu, postgres_scanner, fts and vss are bundled.
      Load them by name, for example LOAD httpfs; or LOAD postgres;.
      HNSW indexes currently require an in-memory database.
      This preview targets DuckDB 1.5.6. It is independently maintained.
    EOS
  end

  test do
    sql = <<~SQL
      SET custom_extension_repository='http://127.0.0.1:1';
      SET extension_directory='#{testpath}/extensions';
      INSTALL fts;
      INSTALL vss;
      LOAD fts;
      LOAD vss;
      CREATE TABLE docs(id INTEGER, body VARCHAR);
      INSERT INTO docs VALUES (1,'red fox'),(2,'blue bird');
      PRAGMA create_fts_index('docs','id','body');
      SELECT CASE WHEN count(*)=1 THEN 'fts-ok' ELSE error('FTS failure') END FROM docs WHERE fts_main_docs.match_bm25(id,'fox') IS NOT NULL;
      CREATE TABLE vectors(id INTEGER,v FLOAT[3]);
      INSERT INTO vectors VALUES (1,[1,0,0]),(2,[0,1,0]);
      CREATE INDEX h ON vectors USING HNSW(v);
      SELECT CASE WHEN id=1 THEN 'vss-ok' ELSE error('VSS failure') END FROM (SELECT id FROM vectors ORDER BY array_distance(v,[1,0,0]::FLOAT[3]) LIMIT 1);
      EXPLAIN SELECT id FROM vectors ORDER BY array_distance(v,[1,0,0]::FLOAT[3]) LIMIT 1;
      INSTALL httpfs;
      LOAD httpfs;
      LOAD aws;
      LOAD azure;
      LOAD icu;
      LOAD postgres_scanner;
      SELECT CASE WHEN count(*)=5 THEN 'extensions-ok' ELSE error('extension load failure') END FROM duckdb_extensions() WHERE loaded AND extension_name IN ('httpfs','aws','azure','icu','postgres_scanner');
      SELECT CASE WHEN 'a' COLLATE en < 'B' AND (TIMESTAMPTZ '2024-01-01 00:00:00+00' AT TIME ZONE 'Asia/Tokyo')::VARCHAR = '2024-01-01 09:00:00' THEN 'icu-ok' ELSE error('ICU failure') END;
      CREATE SECRET brew_s3 (TYPE s3, KEY_ID 'test', SECRET 'test', REGION 'eu-west-1');
      SELECT CASE WHEN count(*)=1 THEN 'secret-ok' ELSE error('secret failure') END FROM duckdb_secrets() WHERE name='brew_s3' AND type='s3';
      SELECT CASE WHEN count(*)>0 THEN 'postgres-ok' ELSE error('postgres failure') END FROM duckdb_functions() WHERE function_name='postgres_scan';
    SQL
    output = pipe_output("#{bin}/roastedduck".shellescape + " -batch -bail -init /dev/null :memory:", sql, 0)
    assert_match "fts-ok", output
    assert_match "vss-ok", output
    assert_match "HNSW_INDEX_SCAN", output
    assert_match "extensions-ok", output
    assert_match "icu-ok", output
    assert_match "secret-ok", output
    assert_match "postgres-ok", output
  end
end
