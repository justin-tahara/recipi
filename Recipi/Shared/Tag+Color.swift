import RecipiDesign
import RecipiKit

extension Tag {
    /// The color the person picked for this tag, or the one its name
    /// hashes to.
    var color: TagColor {
        TagColor.forTag(named: name, override: colorOverride)
    }
}
