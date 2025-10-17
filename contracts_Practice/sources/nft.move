/// ワークショップ向けの最小構成 NFT コントラクトです。
/// 学べること:
/// - オブジェクト（object）ベースの NFT をミントする方法
/// - エントリ関数でミントした NFT をウォレットへ転送する手順
/// - Display（表示用メタデータ）の初期化と Publisher の請求方法
/// 注意: 学習用サンプルのため、権限制御や高度な検証は意図的に最小限です。
module nft::nft;

// よく使う標準/フレームワークのモジュールを `use` して短く呼べるようにします。
use std::string::String;
use sui::display;
use sui::package;

// Display 初期化時の Publisher 請求に使うワンタイムウィットネス。
// パッケージ publish 時に自動で与えられ、`package::claim` に使います。
public struct NFT has drop {}

// ミントされる NFT 本体。
// - `key` 能力: Sui台帳で「独自のIDを持つオブジェクト」であることを示します。
// - `store` 能力: 他モジュールへ移動（転送）できるようにします。
public struct WorkshopNFT has key, store {
    id: UID,          // Sui が管理するユニークID（必須）
    name: String,     // 表示名
    description: String, // 説明文
    image_url: String,// 画像URL（IPFSやHTTPSなど）
    creator: address,         // 作成者（ミント時の送信者）
}

// 入力バリデーション用のエラーコード。
const EEmptyName: u64 = 1;
const EEmptyImageUrl: u64 = 2;
const EInvalidNamesLength: u64 = 3;
const EInvalidDescriptionsLength: u64 = 4;
const EInvalidImageUrlsLength: u64 = 5;

// パッケージ publish 時に Display を作成・共有する初期化ロジック。
// Suiのinitializerは `fun init(...)` をモジュール内に定義するだけでOK（属性は不要）。
fun init(witness: NFT, ctx: &mut TxContext) {
    // Publisher を取得（Display の登録に必要）
    let publisher = package::claim(witness, ctx);

    // 表示に使うフィールドテンプレートを登録
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

    // Display のバージョンを進めて有効化し、作成者に転送
    disp.update_version();
    transfer::public_transfer(disp, ctx.sender());
    
    // Publisher を発行者へ返す（保有しておきたいケースが多い）
    transfer::public_transfer(publisher, ctx.sender());
}

// イベント発行は学習をシンプルにするため削除しました。
// その代わり、ミント処理の結果はそのままウォレットに転送します。

// ウォレット送信者に NFT をミントするエントリポイント。
// - 受け取った `name`/`description`/`image_url` を検証してミント
// - できあがった NFT オブジェクトを送信者へ転送
entry fun mint(
    name: String,
    description: String,
    image_url: String,
    ctx: &mut TxContext,
) {
    let nft = mint_internal(name, description, image_url, ctx);
    // `store` 能力があるためどこからでも安全に転送できます。
    transfer::public_transfer(nft, ctx.sender());
}

entry fun mint_bulk(
    quantity: u64,
    mut names: vector<String>,
    mut descriptions: vector<String>,
    mut image_urls: vector<String>,
    ctx: &mut TxContext,
) {
    assert!(names.length() == quantity, EInvalidNamesLength);
    assert!(descriptions.length() == quantity, EInvalidDescriptionsLength);
    assert!(image_urls.length() == quantity, EInvalidImageUrlsLength);

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

// メタデータ取得（UI表示などで便利）。
public fun name(self: &WorkshopNFT): String {
    self.name
}
public fun description(self: &WorkshopNFT): String {
    self.description
}
public fun image_url(self: &WorkshopNFT): String {
    self.image_url
}

// 作成者（ミント時の送信者アドレス）。
public fun creator(self: &WorkshopNFT): address {
    self.creator
}

// 実際のミント処理（ロジック部分）。
// - 入力値を簡単にチェック
// - `object::new(ctx)` で新しいオブジェクトIDを割り当て
// - フィールドを詰めて `WorkshopNFT` を返す
fun mint_internal(
    name: String,
    description: String,
    image_url: String,
    ctx: &mut TxContext,
): WorkshopNFT {
    // ここでは最低限のチェックだけを行います。
    assert!(!name.is_empty(), EEmptyName);
    assert!(!image_url.is_empty(), EEmptyImageUrl);

    WorkshopNFT {
        id: object::new(ctx),
        name,
        description,
        image_url,
        creator: ctx.sender(),
    }
}