# Báo cáo Lab 6: Security Automation và CI/CD

## Thông tin cá nhân

- Họ tên: TODO điền thông tin sinh viên
- MSSV: TODO điền MSSV
- Môn học: NT547 - Blockchain Nền tảng, ứng dụng và bảo mật
- Ngày thực hiện: 2026-05-13
- GitHub repo: https://github.com/jalike576/lab6-security-automation

## Môi trường

Do máy bị chặn cài package Python trực tiếp bằng `pip --user`, Slither được cài trong virtualenv cục bộ:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install slither-analyzer
.venv/bin/solc-select install 0.8.24
.venv/bin/solc-select use 0.8.24
```

Khi chạy lại các lệnh bên dưới, dùng:

```bash
PATH="$PWD/.venv/bin:$PATH"
```

## Yêu cầu 1: Quét lỗi BadVault.sol

File đã tạo: `BadVault.sol`.

Lệnh quét không áp dụng config lọc nhiễu:

```bash
printf '{}' >/tmp/slither-empty.json
PATH="$PWD/.venv/bin:$PATH" slither BadVault.sol --config-file /tmp/slither-empty.json
```

<!-- TODO screenshot: chụp Terminal sau khi chạy lệnh trên, cần thấy danh sách detector và dòng tổng kết "6 result(s) found". -->

Kết quả Slither tìm thấy 6 finding. Các loại lỗi tiêu biểu:

- `reentrancy-eth`: `withdraw()` gọi `msg.sender.call{value: amount}("")` trước khi cập nhật `balances[msg.sender] = 0`, vi phạm Checks-Effects-Interactions.
- `suicidal`: `suicide()` cho phép bất kỳ ai gọi `selfdestruct(payable(owner))`.
- `solc-version`: dùng pragma `^0.8.0`, phạm vi compiler có những version đã biết có issue.
- `low-level-calls`: dùng low-level call trong `withdraw()`.
- `immutable-states`: `owner` có thể khai báo `immutable`.
- `shadowing-builtin`: hàm `suicide()` trùng tên builtin/deprecated symbol.

## Yêu cầu 2: Fix lỗi và quét lại GoodVault.sol

File đã tạo: `GoodVault.sol`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract GoodVault {
    mapping(address => uint256) public balances;
    address public immutable owner;
    bool private locked;

    error NoBalance();
    error TransferFailed();
    error ReentrantCall();

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NoBalance();

        balances[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
```

Lệnh quét:

```bash
printf '{}' >/tmp/slither-empty.json
PATH="$PWD/.venv/bin:$PATH" slither GoodVault.sol --config-file /tmp/slither-empty.json
```

<!-- TODO screenshot: chụp Terminal sau khi chạy lệnh trên, cần thấy Slither chỉ còn finding `low-level-calls` và không còn High/Medium. -->

Kết quả: các lỗi High/Medium đã được khắc phục. Slither chỉ còn `low-level-calls` do contract vẫn dùng `call` để gửi ETH; finding này chấp nhận được trong bài vì code đã dùng CEI, check return value và có `nonReentrant`.

## Yêu cầu 3: Slither config file

File đã tạo: `slither.config.json`.

```json
{
  "exclude_low": true,
  "exclude_informational": true,
  "detectors_to_exclude": "solc-version"
}
```

Lệnh chạy BadVault với config:

```bash
PATH="$PWD/.venv/bin:$PATH" slither BadVault.sol --config-file slither.config.json
```

<!-- TODO screenshot: chụp Terminal sau khi chạy lệnh trên, cần thấy Slither còn 3 result(s) found, ít hơn kết quả Yêu cầu 1 là 6 result(s) found. -->

Kết quả sau khi lọc: còn `reentrancy-eth`, `suicidal`, `immutable-states`. Detector `solc-version` và các finding Low/Informational đã được lọc bỏ.

## Yêu cầu 4: Printers và trực quan hóa

File mẫu đã tạo: `MyNFT.sol`, gồm `Ownable`, `ERC165`, `SimpleERC721`, và `MyNFT` để có cây kế thừa rõ ràng.

Lệnh human-summary:

```bash
PATH="$PWD/.venv/bin:$PATH" slither MyNFT.sol --print human-summary
```

<!-- TODO screenshot: chụp Terminal sau khi chạy lệnh trên, cần thấy bảng summary có contract `MyNFT`, 8 functions, ERC165, và 0 high/medium issue. -->

Tóm tắt kết quả human-summary:

```text
Total number of contracts in source files: 4
Source lines of code (SLOC) in source files: 47
Number of high issues: 0
Number of medium issues: 0
MyNFT: 8 functions, ERC165, Complex code: No
```

Lệnh tạo inheritance graph:

```bash
PATH="$PWD/.venv/bin:$PATH" slither MyNFT.sol --print inheritance-graph
dot -Tpng MyNFT.sol.inheritance-graph.dot -o MyNFT.inheritance-graph.png
```

<!-- TODO screenshot: mở file `MyNFT.inheritance-graph.png` và chụp hình cây kế thừa. Có thể dùng ảnh đã tạo trong thư mục này hoặc upload file `.dot` lên GraphvizOnline. -->

Hình cây kế thừa đã tạo:

![Inheritance graph](MyNFT.inheritance-graph.png)

Ý nghĩa khi audit dự án lớn: cây kế thừa cho auditor thấy nhanh contract nào kế thừa logic nào, modifier nào có thể ảnh hưởng đến hàm public, và thứ tự override/multiple inheritance. Điều này giúp phát hiện rủi ro bị che khuất trong base contract, logic phân quyền nằm ở contract cha, hoặc xung đột override mà nếu chỉ đọc từng file riêng lẻ sẽ dễ bỏ sót.

## Yêu cầu 5: GitHub Actions CI/CD

Repo GitHub: https://github.com/jalike576/lab6-security-automation

File workflow đã tạo: `.github/workflows/slither.yml`.

```yaml
name: Slither

on:
  push:
    branches:
      - main

jobs:
  slither:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Slither
        uses: crytic/slither-action@v0.4.1
        with:
          target: BadVault.sol
          solc-version: 0.8.24
          fail-on: high
```

Workflow được cấu hình chạy khi `push` vào nhánh `main`. Vì `BadVault.sol` có finding High (`reentrancy-eth`, `suicidal`), job sẽ fail khi gặp High Severity theo `fail-on: high`.

<!-- TODO screenshot: sau khi push lên GitHub, vào repo -> tab Actions -> workflow `Slither`, chụp màn hình run mới nhất. Cần chụp trang thể hiện job Slither fail do Slither tìm thấy lỗi High Severity trong `BadVault.sol`. -->

Có thể kiểm tra run bằng GitHub CLI:

```bash
gh run list --repo jalike576/lab6-security-automation --limit 5
```

<!-- TODO screenshot tùy chọn: chụp Terminal lệnh `gh run list --repo jalike576/lab6-security-automation --limit 5` để thấy status workflow. -->

## Câu hỏi tư duy

Static Analysis như Slither nhanh hơn vì nó đọc mã nguồn/AST/CFG và áp dụng tập rule có sẵn mà không cần deploy contract, sinh input, hay chạy nhiều trạng thái runtime. Nó có thể quét toàn bộ code trong vài giây và chi phí tính toán thấp.

Nhưng Static Analysis dễ có false positive hơn Fuzzing hoặc Formal Verification vì nó không biết đầy đủ ngữ cảnh vận hành, invariant nghiệp vụ, giá trị runtime và ràng buộc môi trường. Slither thường báo theo pattern nguy hiểm, vì vậy một pattern có thể an toàn trong ngữ cảnh cụ thể vẫn bị cảnh báo. Fuzzing kiểm tra bằng cách sinh input và thực thi contract nên bằng chứng gần runtime hơn, còn Formal Verification chứng minh theo đặc tả nên chính xác hơn nếu đặc tả đúng, nhưng đòi hỏi thời gian và công sức lớn hơn.
