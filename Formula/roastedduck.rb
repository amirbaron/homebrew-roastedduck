require "shellwords"

class Roastedduck < Formula
  desc "Analytical SQL engine in Rust with bundled DuckDB-compatible extensions"
  homepage "https://amirbaron.github.io/roastedDuck/"
  version "1.5.6.post6"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :big_sur
    url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post6/roastedduck-1.5.6.post6-macos-arm64.tar.gz"
    sha256 "30c10bf9ddcb50e4bfe14a1dd50acb3083008a921bbfa4ac9a601809542db8db"
  end

  on_linux do
    on_arm do
      url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post6/roastedduck-1.5.6.post6-linux-arm64.tar.gz"
      sha256 "94207cdb465fe2ca516339bff7dab007726c6361e7315d43a3918ba9db6434f0"
    end
    on_intel do
      url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post6/roastedduck-1.5.6.post6-linux-amd64.tar.gz"
      sha256 "07fb1daa2b05dc9078ccc7ab3e20f7eb462a1763157fe800ff23a8dfccf5f2bd"
    end
  end

  def install
    bin.install "bin/roastedDuck" => "roastedduck"
    bin.install_symlink "roastedduck" => "roastedDuck" unless (bin/"roastedDuck").exist?
    pkgshare.install "notices", "LICENSE", "THIRD_PARTY_NOTICES.md"
  end

  def caveats
    <<~EOS
      httpfs, aws, azure, icu, postgres_scanner, fts, vss, excel and avro are bundled.
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
      INSTALL avro;
      LOAD avro;
      COPY (SELECT 42 AS value) TO '#{testpath}/smoke.avro' (FORMAT AVRO);
      SELECT CASE WHEN value=42 THEN 'avro-ok' ELSE error('Avro failure') END FROM read_avro('#{testpath}/smoke.avro');
      INSTALL httpfs;
      LOAD httpfs;
      LOAD aws;
      LOAD azure;
      LOAD icu;
      LOAD postgres_scanner;
      INSTALL excel;
      LOAD excel;
      COPY (SELECT 42 AS id) TO 'brew-test.xlsx' (FORMAT XLSX, HEADER true);
      SELECT CASE WHEN max(id)=42 AND count(*)=1 AND excel_text(1234.5, '#,##0.00')='1,234.50'
        THEN 'excel-ok' ELSE error('Excel failure') END FROM 'brew-test.xlsx';
      SELECT CASE WHEN count(*)=5 THEN 'extensions-ok' ELSE error('extension load failure') END FROM duckdb_extensions() WHERE loaded AND extension_name IN ('httpfs','aws','azure','icu','postgres_scanner');
      SELECT CASE WHEN 'a' COLLATE en < 'B' AND (TIMESTAMPTZ '2024-01-01 00:00:00+00' AT TIME ZONE 'Asia/Tokyo')::VARCHAR = '2024-01-01 09:00:00' THEN 'icu-ok' ELSE error('ICU failure') END;
      CREATE SECRET brew_s3 (TYPE s3, KEY_ID 'test', SECRET 'test', REGION 'eu-west-1');
      SELECT CASE WHEN count(*)=1 THEN 'secret-ok' ELSE error('secret failure') END FROM duckdb_secrets() WHERE name='brew_s3' AND type='s3';
      SELECT CASE WHEN count(*)>0 THEN 'postgres-ok' ELSE error('postgres failure') END FROM duckdb_functions() WHERE function_name='postgres_scan';
    SQL
    output = pipe_output("#{bin}/roastedduck".shellescape + " -batch -bail -init /dev/null :memory:", sql, 0)
    assert_match "fts-ok", output
    assert_match "vss-ok", output
    assert_match "avro-ok", output
    assert_match "HNSW_INDEX_SCAN", output
    assert_match "extensions-ok", output
    assert_match "icu-ok", output
    assert_match "secret-ok", output
    assert_match "postgres-ok", output
    assert_match "excel-ok", output
  end
end
