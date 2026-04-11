<p align="center">
<img src="assets/logo.png" alt="RouterBytes" title="RouterBytes" width="512"/>
</p>

<p align="center">
<a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-supported-DE5C43.svg?style=flat"></a>
<a href="blob/main/LICENSE.md"><img src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
</p>

# RouterBytes: A Swift networking library

RouterBytes is a Swift package that provides Swift networking library based on ```APIRouter``` with defined typesafe ```Response```, as well as Authentication

# Features

- Swift6 ready package for networking
- Easily decode body response, header response, or both definable for each ```APIRouter```
- Build on async await and ```URLSession```
- Form/Multipart support
- Custom ```Path``` type for improved behavior of computing path consisting of multiple parts
- Includes ```RouterBytesAuthentication``` for defining types interface for refreshing tokens
- TokenManager for automatic refreshing of access token via APIRouter request with refresh token.
- Firebase support for as token manager via [CleevioFirebaseAuth](https://github.com/cleevio/CleevioFirebaseAuth)

## Usage/Examples

For detailed usage/examples check documentation.

## Migration

For `1.0.0` API changes (HTTP Types migration + `HeaderResponse` flow), see [Migration Guide](MIGRATION.md).

## Contributing

Contributions to RouterBytes are welcome!
Here are a few ways you can contribute:

- Add (or improve) support for more platforms
- Migration to Swift http types
- Any conceptual contributions are quite welcome
- Fix bugs or issues

If you'd like to contribute, create a new branch for your work. Once you're finished, create a merge request and we'll review your changes.

## License

[MIT](LICENSE.md)

## Developed by

The good guys from [Cleevio](https://cleevio.com).

![Cleevio logo](assets/cleevio.png)
