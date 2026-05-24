import { QuartzComponent, QuartzComponentConstructor, QuartzComponentProps } from "./types"
import { resolveRelative, FullSlug, SimpleSlug, simplifySlug } from "../util/path"
import { classNames } from "../util/lang"

interface RelatedOptions {
  title?: string
  hideWhenEmpty: boolean
}

const defaultOptions: RelatedOptions = {
  title: "Related",
  hideWhenEmpty: true,
}

export default ((opts?: Partial<RelatedOptions>) => {
  const options: RelatedOptions = { ...defaultOptions, ...opts }

  const Related: QuartzComponent = ({ fileData, allFiles, displayClass }: QuartzComponentProps) => {
    const related = (fileData.frontmatter?.related ?? []) as SimpleSlug[]

    // Map related strings to files
    const relatedFiles =
      related
        .map((rel) => {
          // Try to match by slug first
          const bySlug = allFiles.find((f) => {
            const s = simplifySlug(f.slug!)
            return s === rel || s.endsWith("/" + rel)
          })
          if (bySlug) return bySlug

          // Fallback: try matching by permalink (aliases pushed into fileData.aliases by Frontmatter transformer)
          const byAlias = allFiles.find((f) =>
            f.aliases?.map(simplifySlug).some((a) => a === rel || a.endsWith("/" + rel)),
          )
          if (byAlias) return byAlias

          // Fallback: try matching by title
          const byTitle = allFiles.find((f) => f.frontmatter?.title === rel)
          return byTitle
        })
        .filter((f) => f != null) ?? []

    if (options.hideWhenEmpty && relatedFiles.length === 0) {
      return null
    }

    return (
      <div class={classNames(displayClass, "related")}>
        <h3>{options.title}</h3>
        <ul>
          {relatedFiles.length > 0 ? (
            relatedFiles.map((f) => (
              <li>
                <a
                  href={resolveRelative(fileData.slug! as FullSlug, f.slug! as FullSlug)}
                  class="internal"
                >
                  {f.frontmatter?.title ?? f.slug}
                </a>
              </li>
            ))
          ) : (
            <li>No related content found</li>
          )}
        </ul>
      </div>
    )
  }

  Related.css = `
.related {
  margin: 1.5rem 0 0 0;
}
.related h3 {
  margin: 0 0 0.75rem 0;
}
.related ul {
  list-style: none;
  padding: 0;
  margin: 0;
}
.related li {
  margin: 0.25rem 0;
}
`

  return Related
}) satisfies QuartzComponentConstructor
