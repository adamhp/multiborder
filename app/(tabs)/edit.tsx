import { Text, View } from 'react-native';
import i18n from '../../assets/locales';
import { PageContainer } from './_layout';

export default function EditScreen() {
  return (
    <PageContainer>
      <Text>{i18n.t('settings')}</Text>
      <View />
    </PageContainer>
  );
}
