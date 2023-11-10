import { Button, StyleSheet, Text, View } from 'react-native';

import EditScreenInfo from '../../components/EditScreenInfo';
import { useRecoilValue } from 'recoil';
import { imagesRefs } from '../state';

export default function TabTwoScreen() {
  const imagesRefsState = useRecoilValue(imagesRefs);
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Export</Text>
      <Button
        onPress={() => {
          imagesRefsState.map((func) => {
            func();
          });
        }}
        title='Save'
      />
      <EditScreenInfo path='app/(tabs)/export.tsx' />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  separator: {
    marginVertical: 30,
    height: 1,
    width: '80%',
  },
});
