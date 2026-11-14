require "shellwords"

class Roastedduck < Formula
  desc "Analytical SQL engine in Rust with bundled compatible FTS and VSS"
  homepage "https://amirbaron.github.io/roastedDuck/"
  version "1.5.6.post3"
  license "MIT"

  bottle do
    root_url "https://github.com/amirbaron/homebrew-roastedduck/releases/download/v1.5.6.post3"
    sha256 cellar: :any_skip_relocation, arm64_linux: "edd827f16be25cd523459db1c03f7ec912bb3f6ad206fca4d0879405c7224740"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "e15e2f611eb2a399d8e149ae6a6c6bb03d132024f6dfa7551c055da40fc43af7"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "fbd27b6480098a154241a847f3cb97225c4c9bb6d7ecd4e8011d82e3ae7effc3"
  end

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :big_sur
    url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post3/roastedduck-1.5.6.post3-macos-arm64.tar.gz"
    sha256 "18b694f120040117fc94923c14ec154336e65396b2e727aedf19e222b8d36784"
  end

  on_linux do
    on_arm do
      url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post3/roastedduck-1.5.6.post3-linux-arm64.tar.gz"
      sha256 "6ff4efccb6b63fa407f2e7ba5b0fe122cb6d22d7d75fd840d3b35673f88fbb2f"
    end
    on_intel do
      url "https://github.com/amirbaron/roastedDuck/releases/download/v1.5.6.post3/roastedduck-1.5.6.post3-linux-amd64.tar.gz"
      sha256 "e4be73b23339267f95d29d1f9f9ad41a1373317df5beb0e44604dd716c554122"
    end
  end

  def install
    bin.install "bin/roastedDuck" => "roastedduck"
    bin.install_symlink "roastedduck" => "roastedDuck" unless (bin/"roastedDuck").exist?
    pkgshare.install "notices", "LICENSE", "THIRD_PARTY_NOTICES.md"
  end

  def caveats
    <<~EOS
      FTS and VSS are bundled. Start with LOAD fts; and LOAD vss;.
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
    SQL
    output = pipe_output("#{bin}/roastedduck".shellescape + " -batch -bail -init /dev/null :memory:", sql, 0)
    assert_match "fts-ok", output
    assert_match "vss-ok", output
    assert_match "HNSW_INDEX_SCAN", output
  end
end
