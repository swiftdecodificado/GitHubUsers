import SwiftUI

struct ProfileInfo: View {
    let rows: [InfoRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.info)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    Group {
                        if let url = row.url {
                            Link(destination: url) {
                                cell(row)
                            }
                        } else {
                            cell(row)
                        }
                    }

                    if row.id != rows.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func cell(_ row: InfoRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol(row.kind))
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.info(row.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(row.value)
                    .font(.body)
                    .overflowWrap()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if row.url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 14)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func symbol(_ kind: InfoRow.Kind) -> String {
        switch kind {
        case .company:
            "building.2"
        case .location:
            "mappin.and.ellipse"
        case .blog:
            "link"
        case .twitter:
            "at"
        case .memberSince:
            "calendar"
        }
    }
}

#if DEBUG
    #Preview("Profile Info") {
        ProfileInfo(rows: [
            .init(kind: .company, value: "GitHub", url: nil),
            .init(kind: .location, value: "San Francisco", url: nil),
            .init(kind: .blog, value: "https://github.com", url: URL(string: "https://github.com")),
            .init(kind: .twitter, value: "mojombo", url: URL(string: "https://x.com/mojombo")),
            .init(kind: .memberSince, value: "October 2007", url: nil),
        ])
        .padding()
    }
#endif
