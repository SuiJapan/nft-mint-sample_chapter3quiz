/// ワークショップ向けの練習用穴抜けコードです。
module nft::nft;

// よく使う標準/フレームワークのモジュールを `use` して短く呼べるようにします。
// クイズ1：suiフレームワークsui::display;、sui::package;をインポートしてみよう。
use std::string::String;



public struct NFT has drop {}

//:NFTオブジェクトの本体を作ってみよう
//クイズ2:key,store能力を持たせてみよう

public struct WorkshopNFT has {
    id: UID,          // Sui が管理するユニークID（必須）
                      // クイズ3:表示名nameを追記してみよう
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