# Prisoner searching

Some search fields in re:connect, including the search field within the
address sticker generation section, let you combine a variety of search
terms.

When searching using one of these fields, there are a few search operators
that you can use, which are generally in the format `<type>:<parameter>`.
These operators include:

- `prison:<id>` - All prisoners in the given prison
- `status:"<status>"` - All prisoners with the given status

## Search inclusivity

By default, all prisoners who match **any** of the search terms will be
returned in the search results. To only return prisoners who match **all**
of the search terms, you can add the `all` option.

## Examples

To return all prisoners in the prison with ID `1`: 

```
prison:1
```

To return the list of prisoners who are marked as "Active" who are in the
prison with ID `1`:

```
all prison:1 status:"Active"
```
