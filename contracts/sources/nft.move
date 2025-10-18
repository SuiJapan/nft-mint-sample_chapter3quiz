/// ワークショップ向けの最小構成 NFT コントラクトです。
/// 学べること:
/// - オブジェクト（object）ベースの NFT をミントする方法
/// - エントリ関数でミントした NFT をウォレットへ転送する手順
/// - Display（表示用メタデータ）の初期化と Publisher の請求方法
/// 注意: 学習用サンプルのため、権限制御や高度な検証は意図的に最小限です。
module nft::nft;

// ─────────────────────────────────────────────────────────────
// use … モジュールの読み込み（短い名前で呼べるようにする）
// - std::string::String … 文字列型（Moveの標準ライブラリ）
// - sui::display … NFTの「見た目」メタデータをテンプレートとして登録する仕組み
// - sui::package … Publisher（発行者権限）を請求/管理するためのAPI
//   ※ 実際のビルドでは tx_context / transfer / object / vector なども use しますが、
//     今回は「コードを変えない」要件のため、コメントのみで補足しています。
// ─────────────────────────────────────────────────────────────
use std::string::String;
use sui::display;
use sui::package;

// Display 初期化時の Publisher 請求に使うワンタイムウィットネス（OTW: One-Time Witness）。
// ・この型は「このモジュールの発行者本人である」という証明に使う“印”役のゼロデータ。
// ・パッケージ publish 時に自動で与えられ、`package::claim` で Publisher を生成する際に消費します。
// ・`drop` 能力のみ：保持しても良いし捨てても良い（値として台帳に保存しない想定）。
public struct NFT has drop {}

// ミントされる NFT 本体の型。
// ・`key` 能力 … Sui台帳上で独立したオブジェクトとして保存されることを示す（= `id: UID` が必須）。
// ・`store` 能力 … 他モジュールや他関数へ安全に移動/転送できる。
public struct WorkshopNFT has key, store {
    id: UID,                 // Sui が発行するユニークID（必須フィールド）。このIDにより台帳で追跡可能。
    name: String,            // 表示名（Display でも使用）
    description: String,     // 説明文（Display でも使用）
    image_url: String,       // 画像URL（IPFS/HTTPS などを想定）
    creator: address,        // 作成者（ミント時の送信者アドレスを記録）
}

// 入力バリデーション用のエラーコード定数。
// ・`assert!(条件, エラー番号)` の第2引数として使う。条件が false のとき、その番号で中断（エラー）。
const EEmptyName: u64 = 1;
const EEmptyImageUrl: u64 = 2;
const EInvalidNamesLength: u64 = 3;
const EInvalidDescriptionsLength: u64 = 4;
const EInvalidImageUrlsLength: u64 = 5;

// パッケージ publish 時（＝このモジュールが新規公開/アップグレードされた直後）に一度だけ呼ばれる初期化ロジック。
// ・Sui の initializer は `fun init(...)` を書くだけでよく、特別な属性は不要。
// ・ここでは Display テンプレートを作り、Publisher/Display をデプロイヤーに渡して
//   後から表示を更新できるようにしています。

fun init(witness: NFT, ctx: &mut TxContext) {
    // Publisher を取得（Display の登録/更新に必要な権限オブジェクト）。
    // ・`package::claim` は OTW（ここでは `witness: NFT`）を消費して Publisher を1つ作るAPI。
    // ・1モジュールにつき原則1つ。Publisher 所有者だけがその型の Display を編集可能。
    let publisher = package::claim(witness, ctx);

    // Display（見た目テンプレート）の作成。
    // ・keys … クライアントが参照するメタデータキー（例: "name", "image_url" など）
    // ・values … その値のテンプレート。`{フィールド名}` で型のフィールドを差し込める。
    //   例: `{name}` → WorkshopNFT.name の中身が表示時に入る。
    // 【注意】下記の "link" / "{link}" は、構造体に `link` フィールドが無いサンプルのままです。
    //         実際の運用では、存在しないフィールド名のプレースホルダは空扱い/無視/エラーになる場合があるため、
    //         フィールド名とテンプレートの対応を合わせるのが安全です（ここでは“学習用”のままにしています）。
    let mut disp = display::new_with_fields<WorkshopNFT>(
        &publisher,
        vector[
            b"name".to_string(),
            b"description".to_string(),
            b"image_url".to_string(),
            b"link".to_string(),
        ],
        vector[
            b"{name}".to_string(),
            b"{description}".to_string(),
            b"{image_url}".to_string(),
            b"{link}".to_string(),
        ],
        ctx,
    );

    // Display のバージョンを進めて有効化（登録変更を確定させる操作）。
    // ・Display は編集操作後に `update_version()` を呼んで反映する設計。
    disp.update_version();

    // Display をデプロイヤー（`ctx.sender()`）に転送。
    // ・誰が Display を編集できるか（Publisher保持者とDisplay保持者の分配）をここで決める。
    transfer::public_transfer(disp, ctx.sender());
    
    // Publisher を発行者へ返す（このサンプルではデプロイヤーが保持）。
    // ・後から Display を更新したくなる場合が多いので、Publisher を手元に持たせる。
    transfer::public_transfer(publisher, ctx.sender());
}

// （学習をシンプルにするためイベント発行は省略）
// ・実運用では Mint イベント等を出すと、インデクサ/フロントで追跡しやすい。

// ウォレット送信者に NFT をミントするエントリポイント。
// ・`entry fun` … PTB（Programmable Transaction Block）から直接呼べる公開入口。
// ・受け取った `name`/`description`/`image_url` を検証してミントし、できたNFTを送信者へ転送。
entry fun mint(
    name: String,            // 表示名
    description: String,     // 説明文
    image_url: String,       // 画像URL
    ctx: &mut TxContext,     // トランザクション情報（新規UIDの発行・送信者参照など）
) {
    let nft = mint_internal(name, description, image_url, ctx);
    // `store` 能力があるため、他モジュールからでも安全に転送できる。
    // ここではミント直後に送信者へ渡す“シンプルなミント体験”を提供。
    transfer::public_transfer(nft, ctx.sender());
}

// 複数枚ミント用のエントリポイント（バルクミント）。
// ・`quantity` 件分の name/description/image_url を受け取り、各1枚ずつミントして送信者へ配布。
// ・最初に配列長が quantity と一致するかをチェック（長さ不一致は早期に中断）。
entry fun mint_bulk(
    quantity: u64,                 // ミント枚数
    mut names: vector<String>,     // 各枚の name
    mut descriptions: vector<String>, // 各枚の description
    mut image_urls: vector<String>,   // 各枚の image_url
    ctx: &mut TxContext,
) {
    // 受け取り配列の長さ検証：意図した枚数と一致しなければ中断。
    assert!(names.length() == quantity, EInvalidNamesLength);
    assert!(descriptions.length() == quantity, EInvalidDescriptionsLength);
    assert!(image_urls.length() == quantity, EInvalidImageUrlsLength);

    // quantity 回くり返して 1枚ずつミントして送信者へ渡す処理。
    // ・`pop_back()` … ベクタ末尾から要素を取り出す（可変長配列の基本操作）。
    // ・ここでは「簡潔さ」を優先して、names/descriptions/image_urls を末尾から取り出しています。
    //   （順序が重要な場合は別途整列/インデックス管理を検討）

    quantity.do!(|_| {
        let nft = mint_internal(
            names.pop_back(),
            descriptions.pop_back(),
            image_urls.pop_back(),
            ctx
        );
        transfer::public_transfer(nft, ctx.sender());
    })
}


// 作成者（ミント時の送信者アドレス）。
// ・`creator` を保持しておくと「誰がミントしたか」を後から辿れる（監査・表示で有用）。
public fun creator(self: &WorkshopNFT): address {
    self.creator
}

// 実際のミント処理（ロジック部分）。
// ・入力値を簡単にチェック（名前や画像URLが空は拒否）。
// ・`object::new(ctx)` で新しいオブジェクトID（UID）を割り当てて WorkshopNFT を構築。
// ・返り値の NFT はまだ誰の所有にもなっていないので、呼び出し元で transfer して配る。

fun mint_internal(
    name: String,
    description: String,
    image_url: String,
    ctx: &mut TxContext,
): WorkshopNFT {
    // 最低限の入力検証：名前と画像URLは空文字を禁止。
    // ・エラー番号は上の `const` で定義（テストで期待エラー番号を指定しやすい）。
    assert!(!name.is_empty(), EEmptyName);
    assert!(!image_url.is_empty(), EEmptyImageUrl);

    // 新規オブジェクトの生成：`object::new(ctx)` がユニークな UID を払い出す。
    // ・`creator` には Tx の送信者（`ctx.sender()`）を入れておく。
    WorkshopNFT {
        id: object::new(ctx),
        name,
        description,
        image_url,
        creator: ctx.sender(),
    }
}
